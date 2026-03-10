@tool
@icon("res://Utilities/Debug/EditorIcons/self_knockback_effect.png")
extends KnockbackStats
class_name SelfKnockbackStats
## A special kind of knockback that applies directly to the source entity. Uses either its hands rotation or
## the direction it is facing, as specified. Can also specify a custom direction to override it.

enum DIRECTION_METHOD { FACING, HANDS_ROTATION, CUSTOM }

@export var direction_method: DIRECTION_METHOD = DIRECTION_METHOD.FACING ## What direction vector to apply the knockback in. With "FACING", we apply knockback opposite of anim vector. With "HANDS_ROTATION", we apply it opposite of the direction the hands are facing (useful for gun knockback).


func _get_dynamic_direction(_esi: ESI, entity: Entity, _from_moving_source: bool) -> Vector2:
	return _get_self_knockback_direction(entity)

func _get_rigid_direction(_esi: ESI, entity: RigidEntity, _from_moving_source: bool) -> Vector2:
	return _get_self_knockback_direction(entity)

func _get_self_knockback_direction(entity: Entity) -> Vector2:
	var effect_dir: Vector2 = Vector2.ZERO
	if direction_method == DIRECTION_METHOD.FACING:
		effect_dir = -entity.facing_component.facing_dir.normalized()
	elif direction_method == DIRECTION_METHOD.HANDS_ROTATION:
		var hands_rotation: float = entity.hands.hands_anchor.global_rotation
		effect_dir = -Vector2(cos(hands_rotation), sin(hands_rotation)).normalized()
	else:
		effect_dir = custom_knockback_direction

	return effect_dir
