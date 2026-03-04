extends Resource
class_name EOTI
## EOTI stands for Effect Over Time Instance, and is used as a wrapper for passing EOTs around without
## modifying their original source.

@export var eot: EOTStats: set = _set_eot ## The EOT stats used to drive this EOTI wrapper.
var from_condition: Condition ## The condition that this originated from.
var eot_ticks: Array[int] ## The ticks to apply. Set to copy the eot's ticks originally, but can be overridden.
var duration_override: float = -1 ## The overridable total duration this effect over time instance is applied.
var perpetual_interval_override: float = -1 ## Overridable interval between perpetual ticks.

var dh_handler: DHHandler ## The DH handler this instance is sending updates to in order to apply the ticks.
var time_left: float ## Decremented as the lifetime for this effect over time instance. Acts like its timer.
var delay_time_left: float ## Decremented as the delay time for this instance. Acts like a timer.


func _init(eot_stats: EOTStats) -> void:
	eot = eot_stats

## Setter for the eot stats.
func _set_eot(new_eot: EOTStats) -> void:
	eot = new_eot
	reset_overrides()

## Resets the modifiable overrides back to the original ones in the eot stats.
func reset_overrides() -> void:
	eot_ticks.clear()
	if eot != null:
		eot_ticks.assign(eot.ticks_array)
		eot_ticks.reverse() # Since we use pop_back to access elements.

## Gets the total duration, potentially the overridden version if it has been set.
func get_duration() -> float:
	return eot.duration if duration_override == -1 else duration_override

## Gets the interval between ticks when the effect is perpetual, potentially the overridden version if
## it has been set.
func get_perpetual_interval() -> float:
	return eot.perpetual_interval if perpetual_interval_override == -1 else perpetual_interval_override

func process(delta: float) -> void:
	if delay_time_left > 0:
		delay_time_left -= delta
		if delay_time_left <= 0:
			delay_time_left = 0
			tick()
	else:
		time_left -= delta

func tick() -> void:
	var amount: int = eot_ticks.pop_back()
	dh_handler.send_handled_amount(from_condition.source_type, eot.affected_stats, amount, -1, 0.0, false)
