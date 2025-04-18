@icon("res://Utilities/Debug/EditorIcons/time_snare_handler.svg")
extends Resource
class_name TimeSnareHandler
## A handler for using the data provided in the effect source to apply time snare in different ways.

@export_range(0, 1, 1, "hide_slider", "suffix:(1 = on | 0 = off)") var _time_snare_immunity: float = 0 ## If aything besides 0, the time snare effect is nullified.

var effect_receiver: EffectReceiverComponent ## The receiver that passes the effect to this handler node.


func initialize(receiver: EffectReceiverComponent) -> void:
	effect_receiver = receiver
	assert(effect_receiver.get_parent() is DynamicEntity, effect_receiver.affected_entity.name + " has an effect receiver intended to handle time snares, but the affected entity is not a DynamicEntity.")

	var moddable_stats: Dictionary[StringName, float] = {
		&"time_snare_immunity" : _time_snare_immunity
	}
	effect_receiver.affected_entity.stats.add_moddable_stats(moddable_stats)

func handle_time_snare(time_snare_effect: TimeSnareEffect) -> void:
	if effect_receiver.affected_entity.stats.get_stat("time_snare_immunity") > 0:
		effect_receiver.status_effect_manager.request_effect_removal_for_all_sources("time_snare")
		return

	if effect_receiver.affected_entity is DynamicEntity:
		effect_receiver.affected_entity.request_time_snare(time_snare_effect.time_multiplier, time_snare_effect.snare_time)
