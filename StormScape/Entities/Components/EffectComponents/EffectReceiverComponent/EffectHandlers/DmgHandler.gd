@icon("res://Utilities/Debug/EditorIcons/dmg_handler.svg")
extends Node
class_name DmgHandler
## A handler for using the data provided in the effect source to apply damage in different ways.

@onready var health_component: HealthComponent = get_parent().health_component ## The health component to be affected by the damage.

var dot_timers: Dictionary = {} ## Holds references to all timers currently tracking active DOT.
var dot_delay_timers: Dictionary = {} ## Holds references to all timers current tracking delays for active DOT.


## Asserts that there is a valid health component on the affected entity before trying to handle damage.
func _ready() -> void:
	assert(get_parent().health_component, get_parent().affected_entity.name + " has an effect receiver that is intended to handle damage, but no health component is connected.")

## Calculates the final damage to apply after considering whether the crit hit and also how much the armor blocks.
func _get_dmg_after_crit_then_armor(effect_source: EffectSource) -> int:
	var should_crit: bool = randf() < effect_source.crit_chance
	var dmg_after_crit: int = effect_source.base_damage
	if should_crit: 
		dmg_after_crit = round(dmg_after_crit * effect_source.crit_multiplier)
	
	var armor_block_percent: float = max(0, health_component.armor - effect_source.armor_penetration)
	var new_damage: int = max(0, round(dmg_after_crit * (1 - armor_block_percent)))
	return new_damage

## Handles instantaneous damage that will be affected by armor.
func handle_instant_damage(effect_source: EffectSource) -> void:
	var dmg_after_crit_then_armor: int = _get_dmg_after_crit_then_armor(effect_source)
	_send_handled_dmg(effect_source.dmg_affected_stats, dmg_after_crit_then_armor)

## Handles applying damage that is inflicted over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_dmg(dot_resource: DOTResource, source_type: String) -> void:
	var dot_timer: Timer = Timer.new()
	dot_timer.set_meta("dot_resource", dot_resource)
	dot_timer.set_meta("ticks_completed", 1)
	dot_timer.wait_time = max(0.001, (dot_resource.damaging_time / (dot_resource.dmg_ticks_array.size() - 1)))
	dot_timer.one_shot = false
	dot_timer.timeout.connect(func(): _on_dot_timer_timeout(dot_timer, source_type))
	dot_timer.name = source_type + "_timer" + str(randf())
	add_child(dot_timer)
	
	if dot_resource.delay_time > 0:
		var delay_timer: Timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = dot_resource.delay_time
		delay_timer.timeout.connect(func(): _send_handled_dmg(dot_resource.dmg_affected_stats, dot_resource.dmg_ticks_array[0]))
		delay_timer.timeout.connect(dot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		delay_timer.name = source_type + "_delayTimer" + str(randf())
		add_child(delay_timer)
		delay_timer.start()
		_add_timer_to_cache(source_type, dot_timer, dot_timers)
		_add_timer_to_cache(source_type, delay_timer, dot_delay_timers)
	else:
		_send_handled_dmg(dot_resource.dmg_affected_stats, dot_resource.dmg_ticks_array[0])
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

## Deletes all timers for a source type from the timer cache dict.
func _delete_timers_from_caches(source_type: String) -> void:
	var timers = dot_timers.get(source_type, null)
	if timers:
		for timer in timers:
			if timer != null:
				timer.stop()
				timer.queue_free()
		dot_timers.erase(source_type)
	
	var delay_timers = dot_delay_timers.get(source_type, null)
	if delay_timers:
		for delay_timer in delay_timers:
			if delay_timer != null:
				delay_timer.stop()
				delay_timer.queue_free()
		dot_delay_timers.erase(source_type)

## When the damage over time interval timer ends, check what sourced the timer and see if that source 
## needs to apply any more damage ticks before ending.
func _on_dot_timer_timeout(dot_timer: Timer, source_type: String) -> void:
	var dot_resource: DOTResource = dot_timer.get_meta("dot_resource")
	var ticks_completed: int = dot_timer.get_meta("ticks_completed")
	var max_ticks: int = dot_resource.dmg_ticks_array.size()
	if ticks_completed < max_ticks:
		var damage: int = dot_resource.dmg_ticks_array[ticks_completed]
		var dmg_affected_stats: EnumUtils.DmgAffectedStats = dot_resource.dmg_affected_stats
		_send_handled_dmg(dmg_affected_stats, damage)
		dot_timer.set_meta("ticks_completed", ticks_completed + 1)
		
		if max_ticks == 1:
			_delete_timers_from_caches(source_type)
	else:
		_delete_timers_from_caches(source_type)

## Sends the affected entity's health component the final damage values based on what stats the damage was 
## allowed to affect.
func _send_handled_dmg(dmg_affected_stats: EnumUtils.DmgAffectedStats, handled_amount: int) -> void:
	var positive_dmg: int = max(0, handled_amount)
	match dmg_affected_stats:
		EnumUtils.DmgAffectedStats.HEALTH_ONLY:
			health_component.damage_health(positive_dmg)
		EnumUtils.DmgAffectedStats.SHIELD_ONLY:
			health_component.damage_shield(positive_dmg)
		EnumUtils.DmgAffectedStats.SHIELD_THEN_HEALTH:
			health_component.damage_shield_then_health(positive_dmg)
		EnumUtils.DmgAffectedStats.SIMULTANEOUS:
			health_component.damage_shield(positive_dmg)
			health_component.damage_health(positive_dmg)
