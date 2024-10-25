@icon("res://Utilities/Debug/EditorIcons/heal_handler.svg")
extends Node
class_name HealHandler
## A handler for using the data provided in the effect source to apply healing in different ways.

@onready var health_component: HealthComponent = get_parent().health_component ## The health component to be affected by the healing.

var hot_timers: Dictionary = {} ## Holds references to all timers currently tracking active HOT.
var hot_delay_timers: Dictionary = {} ## Holds references to all timers current tracking delays for active HOT.


## Asserts that there is a valid health component on the affected entity before trying to handle healing.
func _ready() -> void:
	assert(get_parent().health_component, get_parent().affected_entity.name + " has an effect receiver that is intended to handle healing, but no health component is connected.")

## Handles applying instant, one-shot healing to the affected entity.
func handle_instant_heal(base_healing: int, heal_affected_stats: GlobalData.HealAffectedStats) -> void:
	_send_handled_healing(heal_affected_stats, base_healing)

## Handles applying damage that is inflicted over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_heal(hot_resource: HOTResource, source_type: String) -> void:
	var hot_timer: Timer = Timer.new()
	hot_timer.set_meta("hot_resource", hot_resource)
	hot_timer.set_meta("ticks_completed", 1)
	hot_timer.wait_time = max(0.001, (hot_resource.healing_time / (hot_resource.heal_ticks_array.size() - 1)))
	hot_timer.one_shot = false
	hot_timer.timeout.connect(func(): _on_hot_timer_timeout(hot_timer, source_type))
	hot_timer.name = source_type + "_timer"
	add_child(hot_timer)
	
	if hot_resource.delay_time > 0:
		var delay_timer: Timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = hot_resource.delay_time
		delay_timer.timeout.connect(func(): _send_handled_healing(hot_resource.heal_affected_stats, hot_resource.heal_ticks_array[0]))
		delay_timer.timeout.connect(hot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		delay_timer.name = source_type + "_delayTimer"
		add_child(delay_timer)
		delay_timer.start()
		_add_timer_to_cache(source_type, hot_timer, hot_timers)
		_add_timer_to_cache(source_type, delay_timer, hot_delay_timers)
	else:
		_send_handled_healing(hot_resource.heal_affected_stats, hot_resource.heal_ticks_array[0])
		_add_timer_to_cache(source_type, hot_timer, hot_timers)
		hot_timer.start()

## Called externally to stop a HOT effect from proceeding.
func cancel_over_time_heal(source_type: String) -> void:
	_delete_timers_from_caches(source_type)

## Adds a timer to the timer dict cache with the source type as the key.
func _add_timer_to_cache(source_type: String, timer: Timer, cache: Dictionary) -> void:
	if source_type in cache:
		cache[source_type].append(timer)
	else:
		cache[source_type] = [timer]

## Deletes all timers for a source type from the timer cache dict.
func _delete_timers_from_caches(source_type: String) -> void:
	var timers = hot_timers.get(source_type, null)
	if timers:
		for timer in timers:
			if timer != null:
				timer.stop()
				timer.queue_free()
		hot_timers.erase(source_type)
	
	var delay_timers = hot_delay_timers.get(source_type, null)
	if delay_timers:
		for delay_timer in delay_timers:
			if delay_timer != null:
				delay_timer.stop()
				delay_timer.queue_free()
		hot_delay_timers.erase(source_type)

## When the healing over time interval timer ends, check what sourced the timer and see if that source 
## needs to apply any more healing ticks before ending.
func _on_hot_timer_timeout(hot_timer: Timer, source_type: String) -> void:
	var hot_resource: HOTResource = hot_timer.get_meta("hot_resource")
	var ticks_completed: int = hot_timer.get_meta("ticks_completed")
	var max_ticks: int = hot_resource.heal_ticks_array.size()
	if ticks_completed < max_ticks:
		var healing: int = hot_resource.heal_ticks_array[ticks_completed]
		var heal_affected_stats: GlobalData.HealAffectedStats = hot_resource.heal_affected_stats
		_send_handled_healing(heal_affected_stats, healing)
		hot_timer.set_meta("ticks_completed", ticks_completed + 1)
		
		if max_ticks == 1:
			_delete_timers_from_caches(source_type)
	else:
		_delete_timers_from_caches(source_type)

## Sends the affected entity's health component the final healing values based on what stats the heal was 
## allowed to affect.
func _send_handled_healing(heal_affected_stats: GlobalData.HealAffectedStats, handled_amount: int) -> void:
	var positive_healing: int = max(0, handled_amount)
	match heal_affected_stats:
		GlobalData.HealAffectedStats.HEALTH_ONLY:
			health_component.heal_health(positive_healing)
		GlobalData.HealAffectedStats.SHIELD_ONLY:
			health_component.heal_shield(positive_healing)
		GlobalData.HealAffectedStats.HEALTH_THEN_SHIELD:
			health_component.heal_health_then_shield(positive_healing)
		GlobalData.HealAffectedStats.SIMULTANEOUS:
			health_component.heal_health(positive_healing)
			health_component.heal_shield(positive_healing)
