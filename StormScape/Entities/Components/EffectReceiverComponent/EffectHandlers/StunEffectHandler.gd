@icon("res://Utilities/Debug/EditorIcons/stun_effect_handler.svg")
extends Node
## A handler for using the data provided in the effect source to apply stuns in different ways.

@onready var affected_entity: PhysicsBody2D = get_parent().affected_entity ## The entity to be affected by the stun.


func _ready() -> void:
	assert(get_parent().get_parent() is DynamicEntity, get_parent().get_parent().name + " has an effect receiver intended to handle stuns, but the affected entity is not a DynamicEntity.")


## Handles performing a stun effect on the affected entity.
func handle_stun(effect_source: EffectSource) -> void:
	_send_handled_stun(effect_source.dmg_stun_time)

## Sends the resulting stun time to the affected entity as long as it is the right type.
func _send_handled_stun(stun_time: float) -> void:
	if stun_time > 0:
		affected_entity.request_stun(stun_time)
