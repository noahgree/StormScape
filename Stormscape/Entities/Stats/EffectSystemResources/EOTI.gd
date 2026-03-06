extends Resource
class_name EOTI
## EOTI stands for Effect Over Time Instance, and is used as a wrapper for passing EOTs around without
## modifying their original source.

@export var eot_stats: EOTStats: set = _set_eot_stats ## The EOT stats used to drive this EOTI wrapper.
var esi_ticks: Array[int] ## The esi ticks to apply. Set to copy the eot's ticks originally, but can be overridden.
var source_entity: Entity ## The entity that sent out this EOTI.
var esi_receiver: ESIReceiverComponent ## The esi receiver this instance is sending updates to in order to apply the ticks.
var tick_timer: float ## Decremented as the timer between ticks. At each timeout we tick and restart if there are more ticks to work through.
var delay_time_left: float ## Decremented as the delay time for this instance. Acts like a timer.


func _init(eot_stats_resource: EOTStats, src_entity: Entity) -> void:
	eot_stats = eot_stats_resource
	source_entity = src_entity

## Setter for the eot stats.
func _set_eot_stats(new_eot_stats: EOTStats) -> void:
	eot_stats = new_eot_stats
	reset_overrides()

## Resets the modifiable overrides back to the original ones in the eot stats.
func reset_overrides() -> void:
	esi_ticks.clear()
	if eot_stats != null:
		esi_ticks.assign(eot_stats.esi_array)
		esi_ticks.reverse() # Since we use pop_back to access elements.

func process(delta: float) -> void:
	if delay_time_left > 0:
		delay_time_left -= delta
		if delay_time_left <= 0:
			delay_time_left = 0
			tick()
	else:
		time_left -= delta

func tick() -> void:
	var esi: ESI = esi_ticks.pop_back()
	esi_receiver.handle_esi(esi, false)
