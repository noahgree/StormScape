extends State
class_name SneakState
## Handles when the dynamic entity is sneaking, passing a stealth factor back up to the parent entity itself.

const DEFAULT_SNEAK_ANIM_TIME_SCALE: float = 0.65 ## How fast the sneak anim should play before stat mods.


func _init() -> void:
	state_id = "sneak"

func enter() -> void:
	if entity is Player:
		SignalBus.player_sneak_state_changed.emit(true)

func exit() -> void:
	entity.detection_component.update_stealth(0)
	if entity is Player:
		SignalBus.player_sneak_state_changed.emit(false)

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
	StateFunctions.handle_rigid_entity_collisions(entity, controller)

## Updates the dynamic entity with the amount of stealth we currently have.
func _send_parent_entity_stealth_value() -> void:
	entity.detection_component.update_stealth(int(entity.stats.get_stat("max_stealth")))

## If the sneak button is still pressed, continue in this state. Otherwise, transition out based on movement vector.
func _check_if_stopped_sneaking() -> void:
	if controller.get_should_sneak():
		return
	elif controller.get_movement_vector().length() == 0:
		controller.notify_stopped_moving()
	else:
		controller.notify_started_moving()

func _animate() -> void:
	if controller.get_movement_vector() == Vector2.ZERO:
		entity.facing_component.travel_anim_tree("idle")
		entity.facing_component.update_blend_position("idle")
	else:
		entity.facing_component.travel_anim_tree("run")
		entity.facing_component.update_blend_position("run")
