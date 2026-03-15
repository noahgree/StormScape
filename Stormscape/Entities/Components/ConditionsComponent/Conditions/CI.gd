extends Resource
class_name CI
## CI stands for Condition Instance, and is a wrapper around conditions being applied to entities.

signal condition_expired(ci: CI) ## Emitted when this timed CI expires.

@export var condition: Condition ## The condition that this CI wraps.

var eot_stats: EOTStats ## A shorthand of the condition that this CI wrap's eot_stats.
var esi_ticks: Array[ESI] ## The esi ticks to apply. Set to copy the eot's ticks originally, but can be overridden.
var source_entity: Entity ## The entity that sent out this EOTI.
var source_ii: II ## The II that sent out this EOTI.
var affected_entity: Entity ## The entity being affected by this CI.
var tick_timer: float = 0 ## Decremented as the tick timer for this condition instance.
var delay_time_left: float = 0 ## Decremented as the delay time timer for this instance.
var duration_override: float = -1 ## When > 0, this will override the total duration for this CI.
var expiring: bool = false ## Marked true after we emit the condition expired signal to prevent it from firing twice.
var source_esi_uid: int = -1 ## The unique id attained from the ESI that this CI came from.


func _init(src_condition: Condition, src_entity: Entity, src_ii: II, esi_uid: int) -> void:
	condition = src_condition
	eot_stats = condition.eot_stats
	source_entity = src_entity
	source_ii = src_ii

	restart(esi_uid, false)

## Starts or restarts the condition instance as if it were just added to an entity. When called externally,
## we usually don't want to trigger the delay again, as that would make repeated shots that apply this condition
## stuck waiting for the delay to end on every reapplication. So instead, we hit an instant tick.
func restart(new_source_esi_uid: int, instant_tick: bool = true) -> void:
	source_esi_uid = new_source_esi_uid
	if not condition.eot_stats:
		return

	_copy_in_esi_ticks()

	if not instant_tick:
		delay_time_left = condition.eot_stats.tick_delay
	else:
		tick()

	tick_timer = _get_tick_interval()

## Called externally to process the internal tick and delay timers.
func process(delta: float) -> void:
	if not condition.eot_stats:
		_emit_condition_expired_signal()
		return

	if delay_time_left > 0:
		delay_time_left -= delta

		if delay_time_left <= 0:
			delay_time_left = 0
			tick()
	elif tick_timer > 0:
		tick_timer -= delta

		if tick_timer <= 0:
			tick()
			tick_timer = _get_tick_interval()

## Maps each effect source in the eot_stats ticks array to a new ESI in the local esi_ticks array.
func _copy_in_esi_ticks() -> void:
	esi_ticks.clear()

	if (eot_stats.ticks_array.size() != eot_stats.tick_count) and eot_stats.ticks_array.size() != 1:
		push_error(source_entity.name + " has created a CI with EOTStats that do not have the same number of effect sources provided as the number of indicated ticks. Either sync the counts or only use one effect source in the array as the same source for each tick.")

	if not eot_stats.perpetual:
		if eot_stats.ticks_array.size() == 1:
			for i: int in range(eot_stats.tick_count):
				var esi: ESI = ESI.new()
				esi.es = eot_stats.ticks_array[0]
				esi.set_source_info(source_entity, source_ii, condition)
				esi_ticks.append(esi)
		else:
			esi_ticks = eot_stats.ticks_array.map(
				func(es: EffectSource) -> ESI:
					var esi: ESI = ESI.new()
					esi.es = es
					esi.set_source_info(source_entity, source_ii, condition)
					return esi
			)
	else:
		if eot_stats.ticks_array.size() > 0:
			var esi: ESI = ESI.new()
			esi.es = eot_stats.ticks_array[0]
			esi.set_source_info(source_entity, source_ii, condition)
			esi_ticks.append(esi)
		if eot_stats.ticks_array.size() > 1:
			push_warning(source_entity.name + " has created a CI with EOTStats in perpetual mode, but it has more than 1 effect source in the eot_stats ticks array. Only the first index will be used at each tick.")

	esi_ticks.reverse() # Since we use pop_back to access each tick

func _get_tick_interval() -> float:
	if eot_stats.perpetual:
		return eot_stats.perpetual_interval
	return (eot_stats.duration if duration_override <= 0 else duration_override) / eot_stats.tick_count

## Sends out an ESI tick according to whether we are in perpetual mode or not.
func tick() -> void:
	if not eot_stats.perpetual:
		affected_entity.esi_receiver.handle_esi(esi_ticks.pop_back(), false)
		if esi_ticks.is_empty():
			_emit_condition_expired_signal()
	else:
		affected_entity.esi_receiver.handle_esi(esi_ticks.front().copy(), false)

## Emits the signal that this CI has expired, but only if it is not already currently expiring.
func _emit_condition_expired_signal() -> void:
	if not expiring:
		expiring = true
		condition_expired.emit(self)
