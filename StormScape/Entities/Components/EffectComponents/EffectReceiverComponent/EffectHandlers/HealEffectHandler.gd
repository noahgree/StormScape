@icon("res://Utilities/Debug/EditorIcons/heal_effect_handler.svg")
extends Node
## A handler for using the data provided in the effect source to apply healing in different ways.

@onready var health_component: HealthComponent = get_parent().health_component ## The health component to be affected by the healing.


## Asserts that there is a valid health component on the affected entity before trying to handle healing.
func _ready() -> void:
	assert(get_parent().health_component, get_parent().get_parent().name + " has an effect receiver that is intended to handle healing, but no health component is connected.")

## Handles applying instant, one-shot healing to the affected entity.
func handle_instant_heal(effect_source: EffectSource) -> void:
	_send_handled_healing(effect_source.heal_affected_stats, effect_source.base_healing)

## Handles applying healing that is added over time, whether with a delay, with burst intervals, or with both.
func handle_over_time_heal(effect_source: EffectSource) -> void:
	var heal_amount: int = effect_source.base_healing
	
	var hot_timer: Timer = Timer.new()
	hot_timer.set_meta("healing", heal_amount)
	hot_timer.set_meta("heal_affected_stats", effect_source.heal_affected_stats)
	hot_timer.set_meta("ticks_completed", 0)
	hot_timer.wait_time = max(0.001, (effect_source.hot_total_length / effect_source.hot_number_of_ticks))
	hot_timer.one_shot = false
	hot_timer.set_meta("max_ticks", effect_source.hot_number_of_ticks)
	
	hot_timer.timeout.connect(func(): _on_hot_timer_timeout(hot_timer))
	add_child(hot_timer)
	if effect_source.hot_delay_time > 0:
		var delay_timer: Timer = Timer.new()
		delay_timer.one_shot = true
		delay_timer.wait_time = effect_source.hot_delay_time
		delay_timer.timeout.connect(hot_timer.start)
		delay_timer.timeout.connect(delay_timer.queue_free)
		add_child(delay_timer)
		delay_timer.start()
	else:
		hot_timer.start()

## When the healing over time interval timer ends, check what sourced the timer and see if that source 
## needs to apply any more healing ticks before ending.
func _on_hot_timer_timeout(hot_timer: Timer) -> void:
	var ticks_completed: int = hot_timer.get_meta("ticks_completed")
	var max_ticks: int = hot_timer.get_meta("max_ticks")
	if ticks_completed < max_ticks:
		var healing: int = hot_timer.get_meta("healing")
		var heal_affected_stats: EffectSource.HealAffectedStats = hot_timer.get_meta("heal_affected_stats")
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
func _send_handled_healing(heal_affected_stats: EffectSource.HealAffectedStats, handled_amount: int) -> void:
	match heal_affected_stats:
		EffectSource.HealAffectedStats.HEALTH_ONLY:
			health_component.heal_health(handled_amount)
		EffectSource.HealAffectedStats.SHIELD_ONLY:
			health_component.heal_shield(handled_amount)
		EffectSource.HealAffectedStats.HEALTH_THEN_SHIELD:
			health_component.heal_health_then_shield(handled_amount)
		EffectSource.HealAffectedStats.SIMULTANEOUS:
			health_component.heal_health(handled_amount)
			health_component.heal_shield(handled_amount)
