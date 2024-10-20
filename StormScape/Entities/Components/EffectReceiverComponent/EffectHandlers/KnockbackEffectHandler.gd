extends Node
## A handler for using the data provided in the effect source to apply knockback in different ways.

@export_range(0.0, 0.5, 0.01) var entity_dir_influence: float = 0.2

@onready var entity: PhysicsBody2D = get_parent().affected_entity
@onready var effect_receiver: EffectReceiverComponent = get_parent()


## Handles applying knockback to a dynamic entity when they hit something that provides knockback.
func handle_dynamic_entity_knockback(effect_source: EffectSource) -> void:
	var entity_move_dir = entity.velocity.normalized()
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

func _send_handled_knockback(effect_dir: Vector2, force: int) -> void:
	if effect_dir == Vector2.ZERO:
		return
	
	var handled_knockback = effect_dir * force
	
	if entity is DynamicEntity:
		if entity.has_method("request_knockback"):
			entity.request_knockback(handled_knockback)
	elif entity is RigidEntity:
		entity.apply_central_impulse(handled_knockback)
