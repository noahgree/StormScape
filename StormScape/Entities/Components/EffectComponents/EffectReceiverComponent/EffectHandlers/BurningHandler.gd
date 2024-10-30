@icon("res://Utilities/Debug/EditorIcons/burning_handler.svg")
extends Node
class_name BurningHandler
## A handler for using the data provided in the effect source to apply burning in different ways.

@export var _burning_weakness: float = 1.0 ## A multiplier for burning damage on an entity.
@export var _burning_resistance: float = 1.0 ## A multiplier for burning reduction on an entity.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.


## Sets up moddable stats.
func _ready() -> void:
	var moddable_stats: Dictionary = {
		"burning_weakness" : _burning_weakness, "burning_resistance" : _burning_resistance
	}
	effect_receiver.affected_entity.stats.add_moddable_stats(moddable_stats)

func handle_burning(burning_effect: BurningEffect) -> void:
	if burning_effect.dot_resource != null: # needed for when we nullify on game load
		var local_dot_resource: DOTResource = burning_effect.dot_resource.duplicate()
		var burning_weakness: float = effect_receiver.affected_entity.stats.get_stat("burning_weakness")
		var burning_resistance: float = effect_receiver.affected_entity.stats.get_stat("burning_resistance")
		
		for i in range(local_dot_resource.dmg_ticks_array.size()):
			local_dot_resource.dmg_ticks_array[i] = int(roundf(local_dot_resource.dmg_ticks_array[i] * (1 + burning_weakness - burning_resistance)))
		
		(effect_receiver.get_node("DmgHandler") as DmgHandler).handle_over_time_dmg(local_dot_resource, "Burning")
