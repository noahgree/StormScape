extends Resource
class_name EOTI
## EOTI stands for Effect Over Time Instance, and is used as a wrapper for passing EOTs around without
## modifying their original source.

signal all_ticks_completed(condition_id: Condition.ID, source_type: Condition.SourceType, eoti_uid: int) ## Fired when all ticks have been sent out. Only works for non-perpetuals.

@export var eot_stats: EOTStats: set = _set_eot_stats ## The EOT stats used to drive this EOTI wrapper.

var esi_ticks: Array[ESI] ## The esi ticks to apply. Set to copy the eot's ticks originally, but can be overridden.
var source_entity: Entity ## The entity that sent out this EOTI.
var source_ii: II ## The II that sent out this EOTI.
var source_condition: Condition ## The condition that this EOTI is associated with.
var esi_receiver: ESIReceiverComponent ## The esi receiver this instance is sending updates to in order to apply the ticks.
var tick_timer: float ## Decremented as the timer between ticks. At each timeout we tick and restart if there are more ticks to work through.
var delay_time_left: float ## Decremented as the delay time for this instance. Acts like a timer.
var uid: int = -1 ## The unique identifier assigned to this EOTI when handled by the DHHandler.


func _init(eot_stats_resource: EOTStats, src_entity: Entity, src_ii: II, src_condition: Condition) -> void:
	eot_stats = eot_stats_resource
	source_entity = src_entity
	source_ii = src_ii
	source_condition = src_condition

## Setter for the eot stats.
func _set_eot_stats(new_eot_stats: EOTStats) -> void:
	eot_stats = new_eot_stats
	reset_overrides()
	copy_in_esi_ticks()

## Resets the modifiable overrides back to the original ones in the eot stats.
func reset_overrides() -> void:
	esi_ticks.clear()
	if eot_stats != null:
		esi_ticks.assign(eot_stats.esi_array)
		esi_ticks.reverse() # Since we use pop_back to access elements.

## Gets the key for this EOTI, which is an array as [source_condition.id, source_condition.source_type].
func get_key() -> Array:
	return [source_condition.id, source_condition.source_type]

## Maps each effect source in the eot_stats ticks array to a new ESI in the local esi_ticks array.
func copy_in_esi_ticks() -> void:
	if (eot_stats.ticks_array.size() != eot_stats.tick_count) and eot_stats.ticks_array.size() != 1:
		push_error(source_entity.name + " has created an EOTI that does not have the same number of effect sources provided as the number of indicated ticks. Either sync the counts or only use one effect source in the array as the same source for each tick.")

	if not eot_stats.perpetual:
		if eot_stats.ticks_array.size() == 1:
			for i: int in range(eot_stats.tick_count):
				var esi: ESI = ESI.new()
				esi.es = eot_stats.ticks_array[0]
				esi.set_source_info(source_entity, source_ii, source_condition)
				esi_ticks[i] = esi
		else:
			esi_ticks = eot_stats.ticks_array.map(
				func(es: EffectSource) -> ESI:
					var esi: ESI = ESI.new()
					esi.es = es
					esi.set_source_info(source_entity, source_ii, source_condition)
					return esi
			)
	else:
		if eot_stats.ticks_array.size() > 0:
			var esi: ESI = ESI.new()
			esi.es = eot_stats.ticks_array[0]
			esi.set_source_info(source_entity, source_ii, source_condition)
			esi_ticks[0] = esi
		if eot_stats.ticks_array.size() > 1:
			push_warning(source_entity.name + "has created an EOTI in perpetual mode, but it has more than 1 effect source in the eot_stats ticks array. Only the first index will be used at each tick.")

## Called externally to process the internal tick and delay timers.
func process(delta: float) -> void:
	if delay_time_left > 0:
		delay_time_left -= delta

		if delay_time_left <= 0:
			delay_time_left = 0
			tick()
	else:
		tick_timer -= delta

		if tick_timer <= 0:
			tick_timer = 0
			tick()

## Sends out an ESI tick according to whether we are in perpetual mode or not. Signals if all ticks are done.
func tick() -> void:
	if not eot_stats.perpetual:
		esi_receiver.handle_esi(esi_ticks.pop_back(), false)
		if esi_ticks.is_empty():
			all_ticks_completed.emit(source_condition.id, source_condition.source_type, uid)
	else:
		esi_receiver.handle_esi(esi_ticks.front().copy(), false)
