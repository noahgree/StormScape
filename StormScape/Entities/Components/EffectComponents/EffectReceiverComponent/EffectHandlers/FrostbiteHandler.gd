@icon("res://Utilities/Debug/EditorIcons/frostbite_handler.svg")
extends Node
class_name FrostbiteHandler

@export var _frostbite_weakness: float = 1.0 ## A multiplier for frostbite damage on an entity.
@export var _frostbite_resistance: float = 1.0 ## A multiplier for frostbite reduction on an entity.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.


## Sets up moddable stats.
func _ready() -> void:
	assert(get_parent().has_node("DmgHandler"), get_parent().get_parent().name + " has a FrostbiteHandler but no DmgHandler.")

	var moddable_stats: Dictionary = {
		"frostbite_weakness" : _frostbite_weakness, "frostbite_resistance" : _frostbite_resistance
	}
	effect_receiver.affected_entity.stats.add_moddable_stats(moddable_stats)


func handle_frostbite(frostbite_effect: FrostbiteEffect) -> void:
	if frostbite_effect.dot_resource != null: # needed for when we nullify on game load
		var local_dot_resource: DOTResource = frostbite_effect.dot_resource.duplicate()
		var frostbite_weakness: float = effect_receiver.affected_entity.stats.get_stat("frostbite_weakness")
		var frostbite_resistance: float = effect_receiver.affected_entity.stats.get_stat("frostbite_resistance")

		for i: int in range(local_dot_resource.dmg_ticks_array.size()):
			local_dot_resource.dmg_ticks_array[i] = int(roundf(local_dot_resource.dmg_ticks_array[i] * (1 + frostbite_weakness - frostbite_resistance)))

		(effect_receiver.get_node("DmgHandler") as DmgHandler).handle_over_time_dmg(local_dot_resource, frostbite_effect.effect_name)
