@tool
@icon("res://Utilities/Debug/EditorIcons/time_snare_effect.png")
extends Condition
class_name TimeSnareStats
## Provides additional condition data to apply time snare in different ways.


#func on_received_regardless_of_level(_esi: ESI, entity: Entity) -> void:
	#var adjusted_time: float = _get_adjusted_time_snare_time(entity)
	#if adjusted_time > 0:
		#(entity as DynamicEntity).fsm.controller.notify_requested_stun(adjusted_time)
#
#func _get_adjusted_time_snare_time(entity: Entity) -> float:
	#var time_snare_weakness: float = entity.sc.get_stat(&"time_snare_weakness")
	#var time_snare_resistance: float = entity.sc.get_stat(&"time_snare_resistance")
#
	#var multiplier: float = 1.0 + (time_snare_weakness / 100.0) - (time_snare_resistance / 100.0)
	#multiplier = clamp(multiplier, 0.0, 2.0)
#
	#return snare_time * multiplier
