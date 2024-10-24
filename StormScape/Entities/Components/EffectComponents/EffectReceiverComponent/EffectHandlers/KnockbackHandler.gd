@icon("res://Utilities/Debug/EditorIcons/knockback_handler.svg")
extends StatBasedComponent
class_name KnockbackHandler
## A handler for using the data provided in the effect source to apply knockback in different ways.

@export var _knockback_boost: float = 1.0 ## A multiplier for knockback on an entity.
@export var _knockback_resistance: float = 1.0 ## A multiplier for redudcing knockback on an entity.
@export_subgroup("Other")
@export_range(0.0, 0.5, 0.01) var entity_dir_influence: float = 0.25 ## How strong of an influence the entity's movement direction should have on the knockback vector.

@onready var affected_entity: PhysicsBody2D = get_parent().affected_entity ## The entity to be affected by the knockback.
@onready var effect_receiver: EffectReceiverComponent = get_parent() ## The receiver that passes the knockback to this handler node.

var contact_position: Vector2 = Vector2.ZERO ## Set by the status effect component for incoming knockback.
var effect_movement_direction: Vector2 = Vector2.ZERO ## Set by the status effect component for incoming knockback.
var is_source_moving_type: bool = false ## Set by the status effect component for incoming knockback.


## Sets up moddable stats.
func _ready() -> void:
	var moddable_stats: Dictionary = {
		"knockback_boost" : _knockback_boost, "knockback_resistance" : _knockback_resistance
	}
	add_moddable_stats(moddable_stats)

## Handles applying knockback to a dynamic entity when they hit something that provides knockback.
func handle_knockback(knockback_effect: KnockbackEffect) -> void:
	if affected_entity is DynamicEntity:
		handle_dynamic_entity_knockback(knockback_effect)
	elif affected_entity is RigidEntity:
		handle_rigid_entity_knockback(knockback_effect)

func handle_dynamic_entity_knockback(knockback_effect: KnockbackEffect) -> void:
	var entity_move_dir = affected_entity.velocity.normalized()
	var effect_dir: Vector2
	if is_source_moving_type:
		if entity_move_dir == Vector2.ZERO:
			effect_dir = effect_movement_direction
		else:
			effect_dir = effect_movement_direction
			effect_dir = effect_dir.lerp(entity_move_dir, entity_dir_influence).normalized()
	else:
		effect_dir = -entity_move_dir
	
	_send_handled_knockback(effect_dir, knockback_effect.knockback_force)

## Handles applying knockback to a rigid entity when it hits something that provides knockback.
func handle_rigid_entity_knockback(knockback_effect: KnockbackEffect) -> void:
	var effect_dir: Vector2
	if is_source_moving_type:
		effect_dir = effect_movement_direction
	else:
		effect_dir = (effect_receiver.global_position - contact_position).normalized()
	
	_send_handled_knockback(effect_dir, knockback_effect.knockback_force)

## Send the resulting handled knockback vector to the affected entity with logic based on what the entity type is.
func _send_handled_knockback(knockback_dir: Vector2, force: int) -> void:
	if knockback_dir == Vector2.ZERO:
		return
	var handled_knockback = knockback_dir * force * (1 + (get_stat("knockback_boost") - get_stat("knockback_resistance")))
	
	if affected_entity is DynamicEntity:
		if affected_entity.has_method("request_knockback"):
			affected_entity.request_knockback(handled_knockback)
	elif affected_entity is RigidEntity:
		affected_entity.apply_central_impulse(handled_knockback)
