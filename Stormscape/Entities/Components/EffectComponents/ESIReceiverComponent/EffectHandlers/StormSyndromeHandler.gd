@icon("res://Utilities/Debug/EditorIcons/storm_syndrome_handler.svg")
extends Resource
class_name StormSyndromeHandler
## A handler for using the data provided in the effect source to apply storm syndrome in different ways.

@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _storm_weakness: float = 0.0 ## A multiplier for increasing storm damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _storm_resistance: float = 0.0 ## A multiplier for reducing storm damage on an entity.

var effect_src_receiver: ESIReceiverComponent ## The receiver that passes the effect to this handler node.


func initialize(receiver: ESIReceiverComponent) -> void:
	effect_src_receiver = receiver
	assert(effect_src_receiver.get_parent() is DynamicEntity, effect_src_receiver.affected_entity.name + " has an esi receiver intended to handle storm syndrome, but the affected entity is not a DynamicEntity.")
	assert(effect_src_receiver.dh_handler, effect_src_receiver.get_parent().name + " has a StormSyndromeHandler but no DHHandler.")

	var moddable_stats: Dictionary[StringName, float] = {
		&"storm_weakness" : _storm_weakness, &"storm_resistance" : _storm_resistance
	}
	effect_src_receiver.affected_entity.sc.add_moddable_stats(moddable_stats)

func handle_storm_syndrome(storm_syndrome_effect: StormSyndromeEffect) -> void:
	if storm_syndrome_effect.dot_resource != null: # needed for when we nullify on game load
		var local_dot_resource: DOTResource = storm_syndrome_effect.dot_resource.duplicate()
		var storm_weakness: float = effect_src_receiver.affected_entity.sc.get_stat("storm_weakness")
		var storm_resistance: float = effect_src_receiver.affected_entity.sc.get_stat("storm_resistance")

		var multiplier: float = 1.0 + (storm_weakness / 100.0) - (storm_resistance / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)

		for i: int in range(local_dot_resource.dmg_ticks_array.size()):
			local_dot_resource.dmg_ticks_array[i] = int(roundf(local_dot_resource.dmg_ticks_array[i] * multiplier))

		(effect_src_receiver.get_node("DHHandler") as DHHandler).handle_over_time_dmg(local_dot_resource, storm_syndrome_effect.get_full_effect_key())
