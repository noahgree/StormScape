extends Resource
class_name EOTI
## EOTI stands for Effect Over Time Instance, and is used as a wrapper for passing EOTs around without
## modifying their original source.

@export var eot: EOTStats: set = _set_eot ## The EOT stats used to drive this EOTI wrapper.
var eot_ticks: Array[int] ## The ticks to apply. Set to copy the eot's ticks originally, but can be overridden.
var duration_override: float = -1 ## The overridable total duration this effect over time instance is applied.
var perpetual_interval_override: float = -1 ## Overridable interval between perpetual ticks.


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

## Gets the total duration, potentially the overridden version if it has been set.
func get_duration() -> float:
	return eot.duration if duration_override == -1 else duration_override

## Gets the ticks to apply, using the copied and potentially modified version that originally came from the eot.
func get_ticks() -> Array[int]:
	return eot_ticks

## Gets the interval between ticks when the effect is perpetual, potentially the overridden version if
## it has been set.
func get_perpetual_interval() -> float:
	return eot.perpetual_interval if perpetual_interval_override == -1 else perpetual_interval_override
