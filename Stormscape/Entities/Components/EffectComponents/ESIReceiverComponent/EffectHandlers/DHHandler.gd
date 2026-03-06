@icon("res://Utilities/Debug/EditorIcons/dh_handler.svg")
extends Node
class_name DHHandler
## DH stands for "damage and healing". This handles applying damage and healing in different ways.

enum Type { DAMAGE, HEALING } ## For differentiating which we are working on when passing values around methods.

@onready var affected_entity: Entity = owner ## The entity affected by this dh handler.
@onready var hp_component: HPComponent = owner.hp_component ## The hp component to be affected by the incoming amounts.

var eot_timers: Dictionary[String, Array] = {} ## Holds references to all timers currently tracking active EOT. Keys are source type ids and values are an array of all matching timers of that type.
var dot_delay_timers: Dictionary[String, Array] = {} ## Holds references to all timers current tracking delays for active DOT.


#region Instant Amounts
func handle_instant_amount(type: Type, popup_type: HPComponent.POPUP_TYPE, esi: ESI) -> int:
	var amount: int = 0
	var is_crit: bool = false
	if type == Type.DAMAGE:
		var base_damage: int = ceili(esi.get_stat(&"base_damage"))
		if base_damage == 0:
			return 0

		var crit_results: Array = _apply_crit_calculations(base_damage, esi)
		is_crit = crit_results[1]
		amount = crit_results[0]
		amount = _apply_level_scaling(amount, esi, Type.DAMAGE)
		amount = _apply_armor_blocking(amount, esi)
		amount = _apply_object_scaling(amount, esi)
	else:
		var base_healing: int = ceili(esi.get_stat(&"base_healing"))
		if base_healing == 0:
			return 0

		amount = _apply_level_scaling(base_healing, esi, Type.HEALING)

	var xp_gain: int = _calculate_resulting_xp(amount)
	popup_type = popup_type if not is_crit else HPComponent.POPUP_TYPE.CRIT_DAMAGE

	send_handled_amount(type, amount, popup_type, esi)

	return xp_gain

func _apply_crit_calculations(base_damage: int, esi: ESI) -> Array:
	var is_crit: bool = (randf_range(0, 100) <= esi.get_stat(&"crit_chance")) and affected_entity.esi_receiver.can_be_crit
	if not is_crit:
		return [base_damage, false]
	return [round(base_damage * esi.get_stat(&"crit_multiplier")), true]

func _apply_level_scaling(amount: int, esi: ESI, type: Type) -> int:
	var level_mult: float = 1.0
	if type == Type.DAMAGE:
		level_mult = ((floori(esi.source_ii_lvl / 10.0) * esi.get_stat(&"lvl_dmg_scalar")) / 100.0) + 1
	else:
		level_mult = ((floori(esi.source_ii_lvl / 10.0) * esi.get_stat(&"lvl_heal_scalar")) / 100.0) + 1
	return ceili(amount * level_mult)

func _apply_armor_blocking(amount: int, esi: ESI) -> int:
	var armor_block_percent: int = max(0, hp_component.armor - esi.get_stat(&"armor_penetration"))
	return max(0, round(amount * (1 - (float(armor_block_percent) / 100))))

func _apply_object_scaling(amount: int, esi: ESI) -> int:
	if not affected_entity.is_object:
		return amount
	return int(amount * esi.get_stat(&"object_damage_mult"))

func _calculate_resulting_xp(amount: int) -> int:
	if amount >= (affected_entity.hp_component.health + affected_entity.hp_component.shield):
		return (amount + WeaponII.LARGE_XP)
	return amount
#endregion


#region Amounts Over Time
## Handles applying damage that is inflicted over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_dmg(dot_resource: DOTResource, source_type: String) -> void:
	var dot_timer: Timer = TimerHelpers.create_repeating_timer(self)
	dot_timer.set_meta("dot_resource", dot_resource)
	dot_timer.name = source_type + "_timer" + str(randf())
	dot_timer.timeout.connect(_on_dot_timer_timeout.bind(dot_timer, source_type))

	if dot_resource.delay_time > 0: # We have a delay before the damage starts
		var delay_timer: Timer = TimerHelpers.create_one_shot_timer(self, dot_resource.delay_time)

		dot_timer.set_meta("ticks_completed", 0)

		if not dot_resource.run_until_removed:
			dot_timer.wait_time = max(0.01, (dot_resource.damaging_time / (dot_resource.dmg_ticks_array.size() - 1)))
		else:
			dot_timer.wait_time = max(0.01, dot_resource.time_between_ticks)

		delay_timer.name = source_type + "_delayTimer" + str(randf())
		delay_timer.timeout.connect(_on_delay_dot_timer_timeout.bind(dot_timer, source_type, delay_timer))
		delay_timer.start()

		TimerHelpers.add_timer_to_cache(source_type, dot_timer, dot_timers)
		TimerHelpers.add_timer_to_cache(source_type, delay_timer, dot_delay_timers)
	else: # There is no delay needed
		dot_timer.set_meta("ticks_completed", 1)

		if not dot_resource.run_until_removed:
			dot_timer.wait_time = max(0.01, (dot_resource.damaging_time / (dot_resource.dmg_ticks_array.size() - 1)))
		else:
			dot_timer.wait_time = max(0.01, dot_resource.time_between_ticks)

		send_handled_amount(source_type, dot_resource.dmg_affected_stats, dot_resource.dmg_ticks_array[0], -1, 0.0, false)
		affected_entity.sprite.start_hitflash(dot_resource.hit_flash_color, false)

		TimerHelpers.add_timer_to_cache(source_type, dot_timer, dot_timers)
		dot_timer.start()

## Called externally to stop a DOT effect from proceeding.
func cancel_over_time_dmg(source_type: String) -> void:
	_cancel_dot_timers(source_type)

	# Cancelling delay timers here as well
	var delay_timers: Array = dot_delay_timers.get(source_type, [])
	if not delay_timers.is_empty():
		TimerHelpers.delete_delay_timers_from_cache(delay_timers)
		if dot_delay_timers[source_type].is_empty():
			dot_delay_timers.erase(source_type)

## Cancels all (or only a specific one) timers for a matching source type.
func _cancel_dot_timers(source_type: String, specific_timer: Timer = null) -> void:
	var damage_timers: Array = dot_timers.get(source_type, [])
	if not damage_timers.is_empty():
		TimerHelpers.delete_timers_from_cache(damage_timers, specific_timer)
		if dot_timers[source_type].is_empty():
			dot_timers.erase(source_type)

## When the delay timer ends, trigger our first tick and then start the normal timer to take it from here.
func _on_delay_dot_timer_timeout(dot_timer: Timer, source_type: String, delay_timer: Timer) -> void:
	_on_dot_timer_timeout(dot_timer, source_type)
	dot_timer.start()
	delay_timer.queue_free()

## When the damage over time interval timer ends, check what sourced the timer and see if that source
## needs to apply any more damage ticks before ending.
func _on_dot_timer_timeout(dot_timer: Timer, source_type: String) -> void:
	var dot_resource: DOTResource = dot_timer.get_meta("dot_resource")
	var ticks_completed: int = dot_timer.get_meta("ticks_completed")
	var dmg_affected_stats: Globals.DmgAffectedStats = dot_resource.dmg_affected_stats

	if dot_resource.run_until_removed:
		var damage: int = dot_resource.dmg_ticks_array[0]
		send_handled_dmg(source_type, dmg_affected_stats, damage, -1, 0.0, false)
		affected_entity.sprite.start_hitflash(dot_resource.hit_flash_color, false)
		dot_timer.set_meta("ticks_completed", ticks_completed + 1)
	else:
		var max_ticks: int = dot_resource.dmg_ticks_array.size()
		if ticks_completed < max_ticks:
			var damage: int = dot_resource.dmg_ticks_array[ticks_completed]
			send_handled_dmg(source_type, dmg_affected_stats, damage, -1, 0.0, false)
			affected_entity.sprite.start_hitflash(dot_resource.hit_flash_color, false)
			dot_timer.set_meta("ticks_completed", ticks_completed + 1)

			if max_ticks == 1:
				_cancel_dot_timers(source_type, dot_timer)
		else:
			_cancel_dot_timers(source_type, dot_timer)
#endregion


## Sends the affected entity's hp component the final amount values based on what stats the amount was
## allowed to affect.
func send_handled_amount(type: Type, amount: int, popup_type: HPComponent.POPUP_TYPE, esi: ESI) -> void:
	if type == Type.DAMAGE:
		var dmg_weakness: float = affected_entity.sc.get_stat(&"dmg_weakness")
		var dmg_resistance: float = affected_entity.sc.get_stat(&"dmg_resistance")
		var multiplier: float = 1.0 + (dmg_weakness / 100.0) - (dmg_resistance / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)
		var clamped_amount: int = max(0, amount * multiplier)

		_handle_life_steal(clamped_amount, esi)
		hp_component.change_by_dh_type(-clamped_amount, popup_type, esi.es.dmg_affected_stats, esi.multishot_id)
	else:
		var heal_affinity: float = affected_entity.sc.get_stat(&"heal_affinity")
		var heal_reduction: float = affected_entity.sc.get_stat(&"heal_reduction")
		var multiplier: float = 1.0 + (heal_affinity / 100.0) - (heal_reduction / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)
		var clamped_amount: int = max(0, amount * multiplier)

		hp_component.change_by_dh_type(clamped_amount, popup_type, esi.es.heal_affected_stats, esi.multishot_id)

	affected_entity.sprite.start_hitflash(esi.es.hit_flash_color, false)

## Handles a life steal interaction, passing the specified percentage of damage dealt back to the source
## entity as healing. Adjusts for life steal weakness and resistance.
func _handle_life_steal(damage_amount: int, esi: ESI) -> void:
	# Skip if source no longer exists and don't allow life steal on something that has infinite HP
	if (esi.source_entity == null) or (affected_entity.hp_component.infinte_hp):
		return

	var ls_condition_index: int = esi.conditions.find(LifeStealStats)
	if ls_condition_index == -1:
		return
	var ls_condition: LifeStealStats = esi.conditions.get(ls_condition_index)

	var self_hp_total: int = affected_entity.hp_component.health + affected_entity.hp_component.shield
	var steal_amount: int = int(floor(min(self_hp_total, damage_amount) * (ls_condition.dmg_steal_pct / 100.0)))

	var ls_weakness: float = affected_entity.sc.get_stat(&"life_steal_weakness")
	var ls_resistance: float = affected_entity.sc.get_stat(&"life_steal_resistance")

	var multiplier: float = 1.0 + (ls_weakness / 100.0) - (ls_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	var clamped_steal_amount: int = max(1, roundi(steal_amount * multiplier))

	esi.source_entity.hp_component.change_by_dh_type(clamped_steal_amount, HPComponent.POPUP_TYPE.LIFE_STEAL, Globals.DHTypes.HEALTH_THEN_SHIELD)
