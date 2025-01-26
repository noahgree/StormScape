extends State
class_name SneakState
## Handles when the dynamic entity is sneaking, passing a stealth factor back up to the parent entity itself.

const DEFAULT_SNEAK_ANIM_TIME_SCALE: float = 0.65 ## How fast the sneak anim should play before stat mods.


func enter() -> void:
	pass

func exit() -> void:
	entity.detection_component.update_stealth(0)

func state_physics_process(delta: float) -> void:
	_do_character_sneak(delta)
	_send_parent_entity_stealth_value()
	_check_if_stopped_sneaking()
	_animate()

func _do_character_sneak(delta: float) -> void:
	if controller.get_movement_vector() == Vector2.ZERO:
		if entity.velocity.length() > (entity.stats.get_stat("friction") * delta): # No input, still slowing
			entity.velocity -= entity.velocity.normalized() * (entity.stats.get_stat("friction") * delta)
		else: # No input, stopped
			controller.knockback_vector = Vector2.ZERO
			entity.velocity = Vector2.ZERO
	else:
		var anim_time_scale: float = DEFAULT_SNEAK_ANIM_TIME_SCALE * (entity.stats.get_stat("max_sneak_speed") / entity.stats.get_original_stat("max_sneak_speed"))
		entity.facing_component.update_time_scale("run", anim_time_scale)

		entity.velocity += (controller.get_movement_vector() * entity.stats.get_stat("sneak_acceleration") * delta)
		entity.velocity = entity.velocity.limit_length(entity.stats.get_stat("max_sneak_speed"))

	entity.move_and_slide()
	_handle_rigid_entity_collisions()

## Handles moving rigid entities that we collided with in the last frame.
func _handle_rigid_entity_collisions() -> void:
	for i: int in entity.get_slide_collision_count():
		var c: KinematicCollision2D = entity.get_slide_collision(i)
		var collider: Object = c.get_collider()
		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal().normalized() * entity.velocity.length() / (15 / (entity.stats.get_stat("sneak_collision_impulse_factor"))))

## Updates the dynamic entity with the amount of stealth we currently have.
func _send_parent_entity_stealth_value() -> void:
	entity.detection_component.update_stealth(int(entity.stats.get_stat("max_stealth")))

## If the sneak button is still pressed, continue in this state. Otherwise, transition out based on movement vector.
func _check_if_stopped_sneaking() -> void:
	if controller.get_should_sneak():
		return

	if controller.get_movement_vector().length() == 0:
		controller.notify_stopped_moving()
	else:
		controller.notify_started_moving()

func _animate() -> void: # FIXME: NEED SNEAK ANIMATION!
	if controller.get_movement_vector() == Vector2.ZERO:
		entity.facing_component.travel_anim_tree("idle")
		entity.facing_component.update_blend_position("idle")
	else:
		entity.facing_component.travel_anim_tree("run")
		entity.facing_component.update_blend_position("run")
