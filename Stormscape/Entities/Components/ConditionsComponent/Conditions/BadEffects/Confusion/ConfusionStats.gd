@tool
extends Condition
class_name ConfusionStats
## Provides additional condition data to apply confusion in different ways.


func on_received_regardless_of_level(_esi: ESI, entity: Entity) -> void:
	var adjusted_time: float = _get_adjusted_confusion_time(entity)
	if adjusted_time > 0:
		(entity as DynamicEntity).fsm.controller.notify_requested_stun(adjusted_time)

func _get_adjusted_confusion_time(entity: Entity) -> float:
	var confusion_weakness: float = entity.sc.get_stat(&"confusion_weakness")
	var confusion_resistance: float = entity.sc.get_stat(&"stun_resistance")

	var multiplier: float = 1.0 + (confusion_weakness / 100.0) - (confusion_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	return eot_stats.duration * multiplier
