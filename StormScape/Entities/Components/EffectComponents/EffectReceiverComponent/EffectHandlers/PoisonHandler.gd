@icon("res://Utilities/Debug/EditorIcons/poison_handler.svg")
extends StatBasedComponent
class_name PoisonHandler
## A handler for using the data provided in the effect source to apply poison in different ways.

@export var _poison_weakness: float = 1.0 ## A multiplier for poison damage on an entity.
@export var _poison_resistance: float = 1.0 ## A multiplier for poison damage on an entity.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.

func _ready() -> void:
	var moddable_stats: Dictionary = {
		"poison_weakness" : _poison_weakness, "poison_resistance" : _poison_resistance
	}
	add_moddable_stats(moddable_stats)

func handle_poison(poison_effect: PoisonEffect) -> void:
	var local_dot_resource: DOTResource = poison_effect.dot_resource.duplicate()
	var poison_weakness: float = get_stat("poison_weakness")
	var poison_resistance: float = get_stat("poison_resistance")
	
	for i in range(local_dot_resource.dmg_ticks_array.size()):
		local_dot_resource.dmg_ticks_array[i] = int(roundf(local_dot_resource.dmg_ticks_array[i] * (1 + poison_weakness - poison_resistance)))
	
	(effect_receiver.get_node("DmgHandler") as DmgHandler).handle_over_time_dmg(local_dot_resource)
