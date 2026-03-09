@tool
@icon("res://Utilities/Debug/EditorIcons/knockback_effect.png")
extends Condition
class_name KnockbackStats
## Provides additional condition data to apply knockback in different ways.

@export var knockback_force: int = 0 ## The magnitude of knockback applied to the entity receiving this damage.
@export var custom_knockback_direction: Vector2  = Vector2.ZERO ## Overrides how knockback wouold normally be applied to send the entity in this direction only. Only change this if you want to override.

const ENTITY_DIR_INFLUENCE: float = 0.25
const RIGID_ENTITY_FORCE_MULT: float = 2.0


func on_received_regardless_of_level(esi: ESI, entity: Entity) -> void:
	var from_moving_source: bool = (esi.es.source_type == ESI.ESISourceType.FROM_PROJECTILE)
	if entity.class_type == Entity.ClassType.DYNAMIC:
		var dir: Vector2 = _get_dynamic_direction(esi, entity, from_moving_source)
		var force: int = _get_force_adjustment(entity)
		(entity as DynamicEntity).fsm.controller.request_knockback(dir * force)
	elif entity.class_type == Entity.ClassType.RIGID:
		var dir: Vector2 = _get_rigid_direction(esi, entity, from_moving_source)
		var force: int = floori(_get_force_adjustment(entity) * RIGID_ENTITY_FORCE_MULT)
		(entity as RigidEntity).apply_central_impulse(dir * force)

func _get_dynamic_direction(esi: ESI, entity: DynamicEntity, from_moving_source: bool) -> Vector2:
	if custom_knockback_direction != Vector2.ZERO:
		return custom_knockback_direction

	var entity_move_dir: Vector2 = entity.velocity.normalized()

	var effect_dir: Vector2 = Vector2.ZERO
	if from_moving_source:
		if entity_move_dir == Vector2.ZERO:
			effect_dir = esi.movement_direction
		else:
			effect_dir = esi.movement_direction
			effect_dir = effect_dir.lerp(entity_move_dir, ENTITY_DIR_INFLUENCE).normalized()
	else:
		if entity_move_dir == Vector2.ZERO:
			effect_dir = (entity.global_position - esi.contact_position).normalized()
		else:
			effect_dir = (entity.global_position - esi.contact_position).normalized()
			effect_dir = effect_dir.lerp(entity_move_dir, ENTITY_DIR_INFLUENCE).normalized()

	return effect_dir

func _get_rigid_direction(esi: ESI, entity: RigidEntity, from_moving_source: bool) -> Vector2:
	if custom_knockback_direction != Vector2.ZERO:
		return custom_knockback_direction

	var effect_dir: Vector2 = Vector2.ZERO
	if from_moving_source:
		effect_dir = esi.movement_direction
	else:
		effect_dir = (entity.global_position - esi.contact_position).normalized()

	return effect_dir

## Send the resulting handled knockback vector to the affected entity with logic based on what the entity type is.
func _get_force_adjustment(entity: Entity) -> int:
	var knockback_weakness: float = entity.sc.get_stat(&"knockback_weakness")
	var knockback_resistance: float = entity.sc.get_stat(&"knockback_resistance")

	var multiplier: float = 1.0 + (knockback_weakness / 100.0) - (knockback_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	return floori(knockback_force * multiplier)
