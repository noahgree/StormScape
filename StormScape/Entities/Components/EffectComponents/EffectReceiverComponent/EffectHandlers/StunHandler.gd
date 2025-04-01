@icon("res://Utilities/Debug/EditorIcons/stun_handler.svg")
extends Node
class_name StunHandler
## A handler for using the data provided in the effect source to apply stuns in different ways.

@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _stun_weakness: float = 0.0 ## A multiplier for increasing stun time applied to an entity.
@export_range(0, 100, 1.0, "hide_slider", "suffix:%") var _stun_resistance: float = 0.0 ## A multiplier for decreasing stun time applied to an entity.

@onready var affected_entity: PhysicsBody2D = get_parent().affected_entity ## The entity to be affected by the stun.


## Asserts that the affected entity is a Dynamic Entity before trying to handle things.
func _ready() -> void:
	assert(get_parent().get_parent() is DynamicEntity, get_parent().affected_entity.name + " has an effect receiver intended to handle stuns, but the affected entity is not a DynamicEntity.")

	var moddable_stats: Dictionary[StringName, float] = {
		&"stun_weakness" : _stun_weakness, &"stun_resistance" : _stun_resistance
	}
	affected_entity.stats.add_moddable_stats(moddable_stats)

## Handles performing a stun effect on the affected entity.
func handle_stun(stun_effect: StunEffect) -> void:
	var stun_weakness: float = affected_entity.stats.get_stat("stun_weakness")
	var stun_resistance: float = affected_entity.stats.get_stat("stun_resistance")

	var multiplier: float = 1.0 + (stun_weakness / 100.0) - (stun_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	var handled_stun_time: float = stun_effect.stun_time * multiplier

	_send_handled_stun(handled_stun_time)

## Sends the resulting stun time to the affected entity as long as it is the right type.
func _send_handled_stun(stun_time: float) -> void:
	if stun_time > 0:
		affected_entity.request_stun(stun_time)
