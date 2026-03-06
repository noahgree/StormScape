@icon("res://Utilities/Debug/EditorIcons/knockback_handler.svg")
extends Resource
class_name KnockbackHandler
## A handler for using the data provided in the effect source to apply knockback in different ways.


const ENTITY_DIR_INFLUENCE: float = 0.25 ## How strong of an influence the entity's movement direction should have on the knockback vector.

var effect_src_receiver: ESIReceiverComponent ## The receiver that passes the effect to this handler node.
var contact_position: Vector2 = Vector2.ZERO ## Set by the condition component for incoming knockback.
var effect_movement_direction: Vector2 = Vector2.ZERO ## Set by the condition component for incoming knockback.
var is_source_moving_type: bool = false ## Set by the condition component for incoming knockback.


func initialize(receiver: ESIReceiverComponent) -> void:
	effect_src_receiver = receiver

## Handles applying knockback to a dynamic entity when they hit something that provides knockback.
func handle_knockback(knockback_effect: KnockbackStats) -> void:
	if knockback_effect.custom_knockback_direction != Vector2.ZERO:
		_send_handled_knockback(knockback_effect.custom_knockback_direction, knockback_effect.knockback_force)
		return

	if knockback_effect is SelfKnockbackStats:
		handle_self_knockback(knockback_effect)
		return

	if effect_src_receiver.affected_entity is DynamicEntity:
		handle_dynamic_entity_knockback(knockback_effect)
	elif effect_src_receiver.affected_entity is RigidEntity:
		handle_rigid_entity_knockback(knockback_effect)

func handle_dynamic_entity_knockback(knockback_effect: KnockbackStats) -> void:
	var entity_move_dir: Vector2 = effect_src_receiver.affected_entity.velocity.normalized()
	var effect_dir: Vector2

	if is_source_moving_type:
		if entity_move_dir == Vector2.ZERO:
			effect_dir = effect_movement_direction
		else:
			effect_dir = effect_movement_direction
			effect_dir = effect_dir.lerp(entity_move_dir, ENTITY_DIR_INFLUENCE).normalized()
	else:
		if entity_move_dir == Vector2.ZERO:
			effect_dir = (effect_src_receiver.global_position - contact_position).normalized()
		else:
			effect_dir = (effect_src_receiver.global_position - contact_position).normalized()
			effect_dir = effect_dir.lerp(entity_move_dir, ENTITY_DIR_INFLUENCE).normalized()

	_send_handled_knockback(effect_dir, knockback_effect.knockback_force)

## Handles applying knockback to a rigid entity when it hits something that provides knockback.
func handle_rigid_entity_knockback(knockback_effect: KnockbackStats) -> void:
	var effect_dir: Vector2

	if is_source_moving_type:
		effect_dir = effect_movement_direction
	else:
		effect_dir = (effect_src_receiver.global_position - contact_position).normalized()

	_send_handled_knockback(effect_dir, knockback_effect.knockback_force * 2)

func handle_self_knockback(knockback_effect: SelfKnockbackStats) -> void:
	if effect_src_receiver.affected_entity is not DynamicEntity:
		push_error("SelfKnockbackStats was attempted to be used on a non-DynamicEntity.")
		return

	var effect_dir: Vector2

	if knockback_effect.direction_method == SelfKnockbackStats.DIRECTION_METHOD.FACING:
		effect_dir = -effect_src_receiver.affected_entity.facing_component.facing_dir.normalized()
	else:
		var hands_rotation: float = effect_src_receiver.affected_entity.hands.hands_anchor.global_rotation
		effect_dir = -Vector2(cos(hands_rotation), sin(hands_rotation)).normalized()

	_send_handled_knockback(effect_dir, knockback_effect.knockback_force)

## Send the resulting handled knockback vector to the affected entity with logic based on what the entity type is.
func _send_handled_knockback(knockback_dir: Vector2, force: int) -> void:
	if knockback_dir == Vector2.ZERO:
		return
	var knockback_weakness: float = effect_src_receiver.affected_entity.sc.get_stat("knockback_weakness")
	var knockback_resistance: float = effect_src_receiver.affected_entity.sc.get_stat("knockback_resistance")

	var multiplier: float = 1.0 + (knockback_weakness / 100.0) - (knockback_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	var handled_knockback: Vector2 = knockback_dir * force * multiplier

	if effect_src_receiver.affected_entity is DynamicEntity:
		if effect_src_receiver.affected_entity.has_method("request_knockback"):
			effect_src_receiver.affected_entity.request_knockback(handled_knockback)
	elif effect_src_receiver.affected_entity is RigidEntity:
		effect_src_receiver.affected_entity.apply_central_impulse(handled_knockback)
