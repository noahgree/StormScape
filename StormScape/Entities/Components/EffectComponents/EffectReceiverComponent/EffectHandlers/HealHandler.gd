@icon("res://Utilities/Debug/EditorIcons/heal_handler.svg")
extends Node
class_name HealHandler
## A handler for using the data provided in the effect source to apply healing in different ways.

@onready var health_component: HealthComponent = get_parent().health_component ## The health component to be affected by the healing.


## Asserts that there is a valid health component on the affected entity before trying to handle healing.
func _ready() -> void:
	assert(get_parent().health_component, get_parent().get_parent().name + " has an effect receiver that is intended to handle healing, but no health component is connected.")

## Handles applying instant, one-shot healing to the affected entity.
func handle_instant_heal(base_healing: int, heal_affected_stats: EnumUtils.HealAffectedStats) -> void:
	_send_handled_healing(heal_affected_stats, base_healing)

## Handles applying healing that is added over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_heal(hot_resource: HOTResource) -> void:
	var hot_timer: Timer = Timer.new()
	hot_timer.set_meta("hot_resource", hot_resource)
	hot_timer.set_meta("ticks_completed", 1)
	hot_timer.wait_time = max(0.001, (hot_resource.healing_time / (hot_resource.heal_ticks_array.size() - 1)))
	hot_timer.one_shot = false
	
	hot_timer.timeout.connect(func(): _on_hot_timer_timeout(hot_timer))
	add_child(hot_timer)
	if hot_resource.delay_time > 0:
		var delay_timer: Timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = hot_resource.delay_time
		delay_timer.timeout.connect(func(): _send_handled_healing(hot_resource.heal_affected_stats, hot_resource.heal_ticks_array[0]))
		delay_timer.timeout.connect(hot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		add_child(delay_timer)
		delay_timer.start()
	else:
		_send_handled_healing(hot_resource.heal_affected_stats, hot_resource.heal_ticks_array[0])
		hot_timer.start()

## When the healing over time interval timer ends, check what sourced the timer and see if that source 
## needs to apply any more healing ticks before ending.
func _on_hot_timer_timeout(hot_timer: Timer) -> void:
	var hot_resource: HOTResource = hot_timer.get_meta("hot_resource")
	var ticks_completed: int = hot_timer.get_meta("ticks_completed")
	var max_ticks: int = hot_resource.heal_ticks_array.size()
	if ticks_completed < max_ticks:
		var healing: int = hot_resource.heal_ticks_array[ticks_completed]
		var heal_affected_stats: EnumUtils.HealAffectedStats = hot_resource.heal_affected_stats
		_send_handled_healing(heal_affected_stats, healing)
		hot_timer.set_meta("ticks_completed", ticks_completed + 1)
		
		if max_ticks == 1:
			hot_timer.stop()
			hot_timer.queue_free()
	else:
		hot_timer.stop()
		hot_timer.queue_free()

## Sends the affected entity's health component the final healing values based on what stats the heal was 
## allowed to affect.
func _send_handled_healing(heal_affected_stats: EnumUtils.HealAffectedStats, handled_amount: int) -> void:
	match heal_affected_stats:
		EnumUtils.HealAffectedStats.HEALTH_ONLY:
			health_component.heal_health(handled_amount)
		EnumUtils.HealAffectedStats.SHIELD_ONLY:
			health_component.heal_shield(handled_amount)
		EnumUtils.HealAffectedStats.HEALTH_THEN_SHIELD:
			health_component.heal_health_then_shield(handled_amount)
		EnumUtils.HealAffectedStats.SIMULTANEOUS:
			health_component.heal_health(handled_amount)
			health_component.heal_shield(handled_amount)
