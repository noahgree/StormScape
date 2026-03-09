extends Resource
class_name CI
## CI stands for Condition Instance, and is a wrapper around conditions being applied to entities.

signal condition_expired(ci: CI) ## Emitted when this timed CI expires.

@export var condition: Condition ## The condition that this CI wraps.

var time_left: float ## Decremented as the lifetime timer for this condition instance.
var delay_time_left: float ## Decremented as the delay time timer for this instance.
var expiring: bool = false ## Marked true after we emit the condition expired signal to prevent it from firing twice.


func _init(condition_source: Condition) -> void:
	condition = condition_source

	if not condition.eot_stats:
		return
	if condition.eot_stats.delay_stats_too:
		delay_time_left = condition.eot_stats.start_delay
	time_left = condition.eot_stats.duration

## Called externally to process the internal lifetime timer and delay timer.
func process(delta: float) -> void:
	if not condition.eot_stats:
		_emit_condition_expired_signal()
		return

	if delay_time_left > 0:
		delay_time_left -= delta
	elif (time_left > 0) and (not condition.eot_stats.perpetual):
		time_left -= delta

		if time_left <= 0:
			_emit_condition_expired_signal()

## Emits the signal that this CI has expired, but only if it is not already currently expiring.
func _emit_condition_expired_signal() -> void:
	if not expiring:
		expiring = true
		condition_expired.emit(self)

## Restarts the lifetime timer and updates the condition reference. Assumes the new condition is the same level.
func restart_time_left(new_condition: Condition) -> void:
	condition = new_condition
	time_left = condition.eot_stats.duration

## Extends the lifetime timer and updates the condition reference. Assumes the new condition is of lower level.
func extend_time_left(new_condition: Condition) -> void:
	var old_level: int = condition.level
	condition = new_condition

	var time_to_add: float = condition.eot_stats.duration * (float(condition.level) / float(old_level))
	time_left += time_to_add
