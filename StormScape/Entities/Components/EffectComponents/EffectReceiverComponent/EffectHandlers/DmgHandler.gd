@icon("res://Utilities/Debug/EditorIcons/dmg_handler.svg")
extends Node
class_name DmgHandler
## A handler for using the data provided in the effect source to apply damage in different ways.

@export var can_be_crit: bool = true ## When false, critical hits are impossible on this entity.
@export var _dmg_weakness: float = 1.0 ## Multiplier for increasing ALL incoming damage.
@export var _dmg_resistance: float = 1.0 ## Multiplier for decreasing ALL incoming damage.

@onready var health_component: HealthComponent = get_parent().health_component ## The health component to be affected by the damage.
@onready var affected_entity: PhysicsBody2D = get_parent().affected_entity ## The entity affected by this dmg handler.

var dot_timers: Dictionary[String, Array] = {} ## Holds references to all timers currently tracking active DOT. Keys are source type names and values are an array of all matching timers of that type.
var dot_delay_timers: Dictionary[String, Array] = {} ## Holds references to all timers current tracking delays for active DOT.


#region Save & Load
func _on_before_load_game() -> void:
	dot_timers = {}
	dot_delay_timers = {}
	for child: Timer in get_children():
		child.queue_free()
#endregion

## Asserts that there is a valid health component on the affected entity before trying to handle damage.
func _ready() -> void:
	assert(get_parent().health_component, affected_entity.name + " has an effect receiver that is intended to handle damage, but no health component is connected.")

	var moddable_stats: Dictionary[StringName, float] = {
		&"dmg_weakness" : _dmg_weakness, &"dmg_resistance" : _dmg_resistance
	}
	affected_entity.stats.add_moddable_stats(moddable_stats)

## Calculates the final damage to apply after considering whether the crit hit and also how much the armor blocks.
func _get_dmg_after_crit_then_armor(effect_source: EffectSource, is_crit: bool) -> int:
	var dmg_after_crit: int = effect_source.base_damage
	if is_crit:
		dmg_after_crit = round(dmg_after_crit * effect_source.crit_multiplier)

	var armor_block_percent: int = max(0, health_component.armor - effect_source.armor_penetration)
	var new_damage: int = max(0, round(dmg_after_crit * (1 - (float(armor_block_percent) / 100))))
	return new_damage

## Handles instantaneous damage that will be affected by armor.
func handle_instant_damage(effect_source: EffectSource, life_steal_percent: float = 0.0) -> void:
	var is_crit: bool = (randf_range(0, 100) <= effect_source.crit_chance) and can_be_crit
	var dmg_after_crit_then_armor: int = _get_dmg_after_crit_then_armor(effect_source, is_crit)

	var object_dmg_mult: float = 1.0
	if (affected_entity is RigidEntity or affected_entity is StaticEntity) and affected_entity.is_object:
		object_dmg_mult = effect_source.object_damage_mult

	_send_handled_dmg("BasicDamage", effect_source.dmg_affected_stats, int(dmg_after_crit_then_armor * object_dmg_mult), effect_source.multishot_id, life_steal_percent, is_crit)

## Handles applying damage that is inflicted over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_dmg(dot_resource: DOTResource, source_type: String) -> void:
	var dot_timer: Timer = TimerHelpers.create_repeating_timer(self)
	dot_timer.set_meta("dot_resource", dot_resource)
	dot_timer.timeout.connect(_on_dot_timer_timeout.bind(dot_timer, source_type))
	dot_timer.name = source_type + "_timer" + str(randf())

	if dot_resource.delay_time > 0: # We have a delay before the damage starts
		var delay_timer: Timer = TimerHelpers.create_one_shot_timer(self, dot_resource.delay_time)

		dot_timer.set_meta("ticks_completed", 0)

		if not dot_resource.run_until_removed:
			dot_timer.wait_time = max(0.01, (dot_resource.damaging_time / (dot_resource.dmg_ticks_array.size() - 1)))
		else:
			dot_timer.wait_time = max(0.01, dot_resource.time_between_ticks)

		delay_timer.timeout.connect(_on_dot_timer_timeout.bind(dot_timer, source_type))
		delay_timer.timeout.connect(dot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		delay_timer.name = source_type + "_delayTimer" + str(randf())
		delay_timer.start()

		_add_timer_to_cache(source_type, dot_timer, dot_timers)
		_add_timer_to_cache(source_type, delay_timer, dot_delay_timers)
	else: # There is no delay needed
		dot_timer.set_meta("ticks_completed", 1)

		if not dot_resource.run_until_removed:
			dot_timer.wait_time = max(0.01, (dot_resource.damaging_time / (dot_resource.dmg_ticks_array.size() - 1)))
		else:
			dot_timer.wait_time = max(0.01, dot_resource.time_between_ticks)

		_send_handled_dmg(source_type, dot_resource.dmg_affected_stats, dot_resource.dmg_ticks_array[0], -1, 0.0, false)
		affected_entity.sprite.start_hitflash(dot_resource.hit_flash_color, false)

		_add_timer_to_cache(source_type, dot_timer, dot_timers)
		dot_timer.start()

## Called externally to stop a DOT effect from proceeding.
func cancel_over_time_dmg(source_type: String) -> void:
	_delete_timers_from_caches(source_type)

## Adds a timer to the timer dict cache with the source type as the key.
func _add_timer_to_cache(source_type: String, timer: Timer, cache: Dictionary) -> void:
	if source_type in cache:
		cache[source_type].append(timer)
	else:
		cache[source_type] = [timer]

## Deletes all timers for a source type from the timer cache dict. Can optionally send a single timer to be the only one removed.
func _delete_timers_from_caches(source_type: String, specific_timer: Timer = null) -> void:
	var timers: Array = dot_timers.get(source_type, [null])
	if timers:
		var to_remove: Array[int] = []
		for i: int in range(timers.size()):
			if timers[i] != null:
				if timers[i] == specific_timer:
					timers[i].queue_free()
					timers.remove_at(i)
					return
				else:
					timers[i].queue_free()
			else:
				to_remove.append(i)

		for i: int in range(to_remove.size()):
			timers.remove_at(to_remove[i])

		dot_timers.erase(source_type)

	var delay_timers: Array = dot_delay_timers.get(source_type, [null])
	if delay_timers:
		delay_timers = delay_timers.filter(func(timer: Variant) -> bool:
			if timer != null:
				timer.queue_free()
				return false  # Remove this timer
			return true  # Keep this timer
		)

		dot_delay_timers.erase(source_type)

## When the damage over time interval timer ends, check what sourced the timer and see if that source
## needs to apply any more damage ticks before ending.
func _on_dot_timer_timeout(dot_timer: Timer, source_type: String) -> void:
	var dot_resource: DOTResource = dot_timer.get_meta("dot_resource")
	var ticks_completed: int = dot_timer.get_meta("ticks_completed")
	var dmg_affected_stats: Globals.DmgAffectedStats = dot_resource.dmg_affected_stats

	if dot_resource.run_until_removed:
		var damage: int = dot_resource.dmg_ticks_array[0]
		_send_handled_dmg(source_type, dmg_affected_stats, damage, -1, 0.0, false)
		affected_entity.sprite.start_hitflash(dot_resource.hit_flash_color, false)
		dot_timer.set_meta("ticks_completed", ticks_completed + 1)
	else:
		var max_ticks: int = dot_resource.dmg_ticks_array.size()
		if ticks_completed < max_ticks:
			var damage: int = dot_resource.dmg_ticks_array[ticks_completed]
			_send_handled_dmg(source_type, dmg_affected_stats, damage, -1, 0.0, false)
			affected_entity.sprite.start_hitflash(dot_resource.hit_flash_color, false)
			dot_timer.set_meta("ticks_completed", ticks_completed + 1)

			if max_ticks == 1:
				_delete_timers_from_caches(source_type, dot_timer)
		else:
			_delete_timers_from_caches(source_type, dot_timer)

## Sends the affected entity's health component the final damage values based on what stats the damage was
## allowed to affect.
func _send_handled_dmg(source_type: String, dmg_affected_stats: Globals.DmgAffectedStats,
						handled_amount: int, multishot_id: int, life_steal_percent: float = 0.0,
						was_crit: bool = false) -> void:
	var dmg_weakness: float = affected_entity.stats.get_stat("dmg_weakness")
	var dmg_resistance: float = affected_entity.stats.get_stat("dmg_resistance")
	var positive_dmg: int = max(0, handled_amount * (1 + dmg_weakness - dmg_resistance))

	_pass_damage_to_potential_life_steal_handler(positive_dmg, life_steal_percent)

	match dmg_affected_stats:
		Globals.DmgAffectedStats.HEALTH_ONLY:
			health_component.damage_health(positive_dmg, source_type, was_crit, multishot_id)
		Globals.DmgAffectedStats.SHIELD_ONLY:
			health_component.damage_shield(positive_dmg, source_type, was_crit, multishot_id)
		Globals.DmgAffectedStats.SHIELD_THEN_HEALTH:
			health_component.damage_shield_then_health(positive_dmg, source_type, was_crit, multishot_id)
		Globals.DmgAffectedStats.SIMULTANEOUS:
			health_component.damage_shield(positive_dmg, source_type, was_crit, multishot_id)
			health_component.damage_health(positive_dmg, source_type, was_crit, multishot_id)

## If we should do life steal, pass that information on to the potential life steal handler.
func _pass_damage_to_potential_life_steal_handler(amount: int, percent_to_steal: float) -> void:
	if percent_to_steal > 0:
		var handler: LifeStealHandler = get_parent().life_steal_handler
		handler.handle_life_steal(amount, percent_to_steal)
