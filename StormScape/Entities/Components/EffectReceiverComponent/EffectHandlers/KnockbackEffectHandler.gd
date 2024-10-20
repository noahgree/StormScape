@icon("res://Utilities/Debug/EditorIcons/knockback_effect_handler.svg")
extends Node
## A handler for using the data provided in the effect source to apply knockback in different ways.

@export_range(0.0, 0.5, 0.01) var entity_dir_influence: float = 0.2 ## How strong of an influence the entity's movement direction should have on the knockback vector.

@onready var affected_entity: PhysicsBody2D = get_parent().affected_entity ## The entity to be affected by the knockback.
@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the knockback to this handler node.


## Handles applying knockback to a dynamic entity when they hit something that provides knockback.
func handle_dynamic_entity_knockback(effect_source: EffectSource) -> void:
	var entity_move_dir = affected_entity.velocity.normalized()
	var effect_dir: Vector2
	if effect_source is MovingEffectSource:
		effect_dir = (effect_source as MovingEffectSource).get_movement_direction()
	elif effect_source is StaticEffectSource:
		var collision_normal: Vector2 = (effect_receiver.global_position - effect_source.global_position).normalized()
		effect_dir = -entity_move_dir.reflect(collision_normal)
	
	var final_dir = ((effect_dir * (1.0 - entity_dir_influence)) + (entity_move_dir * entity_dir_influence)).normalized()
	
	_send_handled_knockback(final_dir, effect_source.knockback_force)

## Handles applying knockback to a rigid entity when it hits something that provides knockback.
func handle_rigid_entity_knockback(effect_source: EffectSource) -> void:
	var effect_dir: Vector2
	if effect_source is MovingEffectSource:
		effect_dir = (effect_source as MovingEffectSource).get_movement_direction()
	elif effect_source is StaticEffectSource:
		effect_dir = (effect_receiver.global_position - effect_source.global_position).normalized()
	
	_send_handled_knockback(effect_dir, effect_source.knockback_force)

## Send the resulting handled knockback vector to the affected entity with logic based on what the entity type is.
func _send_handled_knockback(effect_dir: Vector2, force: int) -> void:
	if effect_dir == Vector2.ZERO:
		return
	
	var handled_knockback = effect_dir * force
	
	if affected_entity is DynamicEntity:
		if affected_entity.has_method("request_knockback"):
			affected_entity.request_knockback(handled_knockback)
	elif affected_entity is RigidEntity:
		affected_entity.apply_central_impulse(handled_knockback)
