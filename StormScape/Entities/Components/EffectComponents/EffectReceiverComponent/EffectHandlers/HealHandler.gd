@icon("res://Utilities/Debug/EditorIcons/heal_handler.svg")
extends Node
class_name HealHandler
## A handler for using the data provided in the effect source to apply healing in different ways.

@onready var health_component: HealthComponent = get_parent().health_component ## The health component to be affected by the healing.

var hot_timers: Dictionary[String, Array] = {} ## Holds references to all timers currently tracking active HOT.
var hot_delay_timers: Dictionary[String, Array] = {} ## Holds references to all timers current tracking delays for active HOT.


#region Save & Load
func _on_before_load_game() -> void:
	hot_timers = {}
	hot_delay_timers = {}
	for child: Timer in get_children():
		child.queue_free()
#endregion

## Asserts that there is a valid health component on the affected entity before trying to handle healing.
func _ready() -> void:
	assert(get_parent().health_component, get_parent().affected_entity.name + " has an effect receiver that is intended to handle healing, but no health component is connected.")

## Handles applying instant, one-shot healing to the affected entity.
func handle_instant_heal(base_healing: int, heal_affected_stats: GlobalData.HealAffectedStats) -> void:
	_send_handled_healing("BasicHealing", heal_affected_stats, base_healing)

## Handles applying damage that is inflicted over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_heal(hot_resource: HOTResource, source_type: String) -> void:
	var hot_timer: Timer = Timer.new()
	hot_timer.set_meta("hot_resource", hot_resource)
	hot_timer.one_shot = false
	hot_timer.timeout.connect(_on_hot_timer_timeout.bind(hot_timer, source_type))
	hot_timer.name = source_type + "_timer"
	add_child(hot_timer)

	if hot_resource.delay_time > 0: # We have a delay before the healing starts
		var delay_timer: Timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = hot_resource.delay_time

		hot_timer.set_meta("ticks_completed", 0)

		if not hot_resource.run_until_removed:
			hot_timer.wait_time = max(0.01, (hot_resource.healing_time / (hot_resource.heal_ticks_array.size() - 1)))
		else:
			hot_timer.wait_time = max(0.01, hot_resource.time_between_ticks)

		delay_timer.timeout.connect(_on_hot_timer_timeout.bind(hot_timer, source_type))
		delay_timer.timeout.connect(hot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		delay_timer.name = source_type + "_delayTimer"
		add_child(delay_timer)
		delay_timer.start()
		_add_timer_to_cache(source_type, hot_timer, hot_timers)
		_add_timer_to_cache(source_type, delay_timer, hot_delay_timers)
	else: # There is no delay needed
		hot_timer.set_meta("ticks_completed", 1)

		if not hot_resource.run_until_removed:
			hot_timer.wait_time = max(0.01, (hot_resource.healing_time / (hot_resource.heal_ticks_array.size() - 1)))
		else:
			hot_timer.wait_time = max(0.01, hot_resource.time_between_ticks)

		_send_handled_healing(source_type, hot_resource.heal_affected_stats, hot_resource.heal_ticks_array[0])
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

## Deletes all timers for a source type from the timer cache dict. Can optionally send a single timer to be the only one removed.
func _delete_timers_from_caches(source_type: String, specific_timer: Timer = null) -> void:
	var timers: Array = hot_timers.get(source_type, [null])
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

		hot_timers.erase(source_type)

	var delay_timers: Array = hot_delay_timers.get(source_type, [null])
	if delay_timers:
		delay_timers = delay_timers.filter(func(timer: Variant) -> bool:
			if timer != null:
				timer.queue_free()
				return false  # Remove this timer
			return true  # Keep this timer
		)

		hot_delay_timers.erase(source_type)

## When the healing over time interval timer ends, check what sourced the timer and see if that source
## needs to apply any more healing ticks before ending.
func _on_hot_timer_timeout(hot_timer: Timer, source_type: String) -> void:
	var hot_resource: HOTResource = hot_timer.get_meta("hot_resource")
	var ticks_completed: int = hot_timer.get_meta("ticks_completed")
	var heal_affected_stats: GlobalData.HealAffectedStats = hot_resource.heal_affected_stats

	if hot_resource.run_until_removed:
		var healing: int = hot_resource.heal_ticks_array[0]
		_send_handled_healing(source_type, heal_affected_stats, healing)
		hot_timer.set_meta("ticks_completed", ticks_completed + 1)
	else:
		var max_ticks: int = hot_resource.heal_ticks_array.size()
		if ticks_completed < max_ticks:
			var healing: int = hot_resource.heal_ticks_array[ticks_completed]
			_send_handled_healing(source_type, heal_affected_stats, healing)
			hot_timer.set_meta("ticks_completed", ticks_completed + 1)

			if max_ticks == 1:
				_delete_timers_from_caches(source_type, hot_timer)
		else:
			_delete_timers_from_caches(source_type, hot_timer)

## Sends the affected entity's health component the final healing values based on what stats the heal was
## allowed to affect.
func _send_handled_healing(source_type: String, heal_affected_stats: GlobalData.HealAffectedStats, handled_amount: int) -> void:
	var positive_healing: int = max(0, handled_amount)
	match heal_affected_stats:
		GlobalData.HealAffectedStats.HEALTH_ONLY:
			health_component.heal_health(positive_healing, source_type)
		GlobalData.HealAffectedStats.SHIELD_ONLY:
			health_component.heal_shield(positive_healing, source_type)
		GlobalData.HealAffectedStats.HEALTH_THEN_SHIELD:
			health_component.heal_health_then_shield(positive_healing, source_type)
		GlobalData.HealAffectedStats.SIMULTANEOUS:
			health_component.heal_health(positive_healing, source_type)
			health_component.heal_shield(positive_healing, source_type)
