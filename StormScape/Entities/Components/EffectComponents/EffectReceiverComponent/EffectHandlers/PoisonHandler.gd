@icon("res://Utilities/Debug/EditorIcons/poison_handler.svg")
extends Resource
class_name PoisonHandler
## A handler for using the data provided in the effect source to apply poison in different ways.

@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _poison_weakness: float = 0.0 ## A multiplier for poison damage on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _poison_resistance: float = 0.0 ## A multiplier for poison damage on an entity.

var effect_receiver: EffectReceiverComponent ## The receiver that passes the effect to this handler node.


func initialize(receiver: EffectReceiverComponent) -> void:
	effect_receiver = receiver
	assert(effect_receiver.dmg_handler, effect_receiver.get_parent().name + " has a PoisonHandler but no DmgHandler.")

	var moddable_stats: Dictionary[StringName, float] = {
		&"poison_weakness" : _poison_weakness, &"poison_resistance" : _poison_resistance
	}
	effect_receiver.affected_entity.stats.add_moddable_stats(moddable_stats)

func handle_poison(poison_effect: PoisonEffect) -> void:
	if poison_effect.dot_resource != null: # Needed for when we nullify on game load
		var local_dot_resource: DOTResource = poison_effect.dot_resource.duplicate()
		var poison_weakness: float = effect_receiver.affected_entity.stats.get_stat("poison_weakness")
		var poison_resistance: float = effect_receiver.affected_entity.stats.get_stat("poison_resistance")

		var multiplier: float = 1.0 + (poison_weakness / 100.0) - (poison_resistance / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)

		for i: int in range(local_dot_resource.dmg_ticks_array.size()):
			local_dot_resource.dmg_ticks_array[i] = int(roundf(local_dot_resource.dmg_ticks_array[i] * multiplier))

		(effect_receiver.get_node("DmgHandler") as DmgHandler).handle_over_time_dmg(local_dot_resource, poison_effect.get_full_effect_key())
