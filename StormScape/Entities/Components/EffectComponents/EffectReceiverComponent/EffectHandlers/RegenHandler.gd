@icon("res://Utilities/Debug/EditorIcons/regen_handler.svg")
extends Node
class_name RegenHandler
## A handler for using the data provided in the effect source to apply regeneration in different ways.

@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _regen_boost: float = 0.0 ## A multiplier for regen boosting on an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _regen_penalty: float = 0.0 ## A multiplier for regen reduction on an entity.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.


## Sets up moddable stats.
func _ready() -> void:
	assert(get_parent().has_node("HealHandler"), get_parent().get_parent().name + " has a RegenHandler but no HealHandler.")

	var moddable_stats: Dictionary[StringName, float] = {
		&"regen_boost" : _regen_boost, &"regen_penalty" : _regen_penalty
	}
	effect_receiver.affected_entity.stats.add_moddable_stats(moddable_stats)


func handle_regen(regen_effect: RegenEffect) -> void:
	if regen_effect.hot_resource != null: # Needed for when we nullify on game load
		var local_hot_resource: HOTResource = regen_effect.hot_resource.duplicate()
		var regen_boost: float = effect_receiver.affected_entity.stats.get_stat("regen_boost")
		var regen_penalty: float = effect_receiver.affected_entity.stats.get_stat("regen_penalty")

		var multiplier: float = 1.0 + (regen_boost / 100.0) - (regen_penalty / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)

		for i: int in range(local_hot_resource.heal_ticks_array.size()):
			local_hot_resource.heal_ticks_array[i] = int(roundf(local_hot_resource.heal_ticks_array[i] * multiplier))

		(effect_receiver.get_node("HealHandler") as HealHandler).handle_over_time_heal(local_hot_resource, regen_effect.get_full_effect_key())
