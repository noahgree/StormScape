@icon("res://Utilities/Debug/EditorIcons/storm_syndrome_handler.svg")
extends Node
class_name StormSyndromeHandler
## A handler for using the data provided in the effect source to apply storm syndrome in different ways.

@export var _storm_weakness: float = 1.0 ## A multiplier for increasing storm damage on an entity.
@export var _storm_resistance: float = 1.0 ## A multiplier for reducing storm damage on an entity.

@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the effect to this handler node.


## Sets up moddable stats.
func _ready() -> void:
	assert(get_parent().get_parent() is DynamicEntity, get_parent().affected_entity.name + " has an effect receiver intended to handle storm syndrome, but the affected entity is not a DynamicEntity.")

	var moddable_stats: Dictionary = {
		"storm_weakness" : _storm_weakness, "storm_resistance" : _storm_resistance
	}
	effect_receiver.affected_entity.stats.add_moddable_stats(moddable_stats)

func handle_storm_syndrome(storm_syndrome_effect: StormSyndromeEffect) -> void:
	if storm_syndrome_effect.dot_resource != null: # needed for when we nullify on game load
		var local_dot_resource: DOTResource = storm_syndrome_effect.dot_resource.duplicate()
		var storm_weakness: float = effect_receiver.affected_entity.stats.get_stat("storm_weakness")
		var storm_resistance: float = effect_receiver.affected_entity.stats.get_stat("storm_resistance")

		for i in range(local_dot_resource.dmg_ticks_array.size()):
			local_dot_resource.dmg_ticks_array[i] = int(roundf(local_dot_resource.dmg_ticks_array[i] * (1 + storm_weakness - storm_resistance)))

		(effect_receiver.get_node("DmgHandler") as DmgHandler).handle_over_time_dmg(local_dot_resource, "Storm Syndrome")
