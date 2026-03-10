@tool
@icon("res://Utilities/Debug/EditorIcons/stun_effect.png")
extends Condition
class_name StunStats
## Provides additional condition data to apply stuns in different ways.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var stun_time: float = 0 ## The amount of time the recipient should be stunned for. Note that this only stuns on the first tick regardless of EOT settings.


func on_received_regardless_of_level(_esi: ESI, entity: Entity) -> void:
	var adjusted_time: float = _get_adjusted_stun_time(entity)
	if adjusted_time > 0:
		(entity as DynamicEntity).fsm.controller.notify_requested_stun(adjusted_time)

func _get_adjusted_stun_time(entity: Entity) -> float:
	var stun_weakness: float = entity.sc.get_stat(&"stun_weakness")
	var stun_resistance: float = entity.sc.get_stat(&"stun_resistance")

	var multiplier: float = 1.0 + (stun_weakness / 100.0) - (stun_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	return stun_time * multiplier
