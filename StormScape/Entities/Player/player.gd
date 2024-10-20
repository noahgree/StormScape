extends DynamicEntity
class_name Player
## The main class for the player character.


func _process(delta: float) -> void:
	move_fsm.state_machine_process(delta)

func _physics_process(delta: float) -> void:
	move_fsm.state_machine_physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	move_fsm.state_machine_handle_input(event)
