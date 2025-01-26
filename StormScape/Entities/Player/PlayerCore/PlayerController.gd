extends DynamicController
class_name PlayerController
## The FSM controller specific to the player.


#region Inputs
func controller_handle_input(event: InputEvent) -> void:
	super.controller_handle_input(event)

	if event.is_action_pressed("dash"):
		notify_requested_dash()
	elif event.is_action_pressed("sneak"):
		notify_requested_sneak()

func get_movement_vector() -> Vector2:
	if get_input_vector() == Vector2.ZERO:
		return Vector2.ZERO
	else:
		return (get_input_vector().rotated(entity.stats.get_stat("confusion_amount")))

func get_should_sneak() -> bool:
	return Input.is_action_pressed("sneak")

func get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
#endregion

#region Core
func controller_process(delta: float) -> void:
	super.controller_process(delta)

	var entity_pos_with_sprite_offset: Vector2 = (entity.sprite.position / 2.0) + entity.global_position
	last_facing_dir = LerpHelpers.lerp_direction(
		last_facing_dir, CursorManager.get_cursor_mouse_position(), entity_pos_with_sprite_offset, entity.facing_component.rotation_lerping_factor
		)
	entity.facing_component.update_facing_dir(last_facing_dir)
#endregion

#region States
func notify_stopped_moving() -> void:
	match fsm.current_state.name:
		"Run", "Sneak", "Dash", "Stunned", "Spawn":
			fsm.change_state("Idle")

func notify_started_moving() -> void:
	match fsm.current_state.name:
		"Idle", "Sneak":
			fsm.change_state("Run")

func notify_requested_dash() -> void:
	match fsm.current_state.name:
		"Run", "Sneak":
			if get_movement_vector().length() == 0:
				return

			var dash_stamina_usage: float = entity.stats.get_stat("dash_stamina_usage")
			if dash_cooldown_timer.is_stopped() and entity.stamina_component.use_stamina(dash_stamina_usage):
				fsm.change_state("Dash")

func notify_requested_sneak() -> void:
	match fsm.current_state.name:
		"Run", "Idle":
			if knockback_vector == Vector2.ZERO:
				fsm.change_state("Sneak")
#endregion
