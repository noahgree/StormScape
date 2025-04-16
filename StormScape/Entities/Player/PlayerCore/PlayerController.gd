extends DynamicController
class_name PlayerController
## The FSM controller specific to the player.


#region Core
func controller_process(delta: float) -> void:
	super.controller_process(delta)
	entity.facing_component.update_facing_dir(facing_method)
#endregion

#region Inputs
func _unhandled_input(event: InputEvent) -> void:
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

#region States
func notify_stopped_moving() -> void:
	match fsm.current_state.state_id:
		"run", "sneak", "dash", "stunned", "spawn":
			fsm.change_state("idle")

func notify_started_moving() -> void:
	match fsm.current_state.state_id:
		"idle", "sneak":
			fsm.change_state("run")
#endregion
