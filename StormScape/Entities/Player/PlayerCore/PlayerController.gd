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
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	return (input_vector.rotated(entity.stats.get_stat("confusion_amount")))

func get_should_sprint() -> bool:
	return Input.is_action_pressed("sprint")

func get_should_sneak() -> bool:
	return Input.is_action_pressed("sneak")
#endregion

#region Core
func controller_process(delta: float) -> void:
	super.controller_process(delta)

	entity.facing_component.update_facing_dir(FacingComponent.Method.MOUSE_POS)
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
