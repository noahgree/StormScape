extends Node
## A handler for using the data provided in the effect source to apply stuns in different ways.

@onready var entity: PhysicsBody2D = get_parent().affected_entity


func handle_stun(effect_source: EffectSource) -> void:
	_send_handled_stun(effect_source.dmg_stun_time)

func _send_handled_stun(stun_time: float) -> void:
	if entity.has_method("request_stun") and stun_time > 0:
		entity.request_stun(stun_time)
