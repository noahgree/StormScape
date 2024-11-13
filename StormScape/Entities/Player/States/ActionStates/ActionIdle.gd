extends ActionState
## Handles when the character is doing nothing in terms of actions. They probably have empty hands.


func enter() -> void:
	pass

func exit() -> void:
	pass

func state_physics_process(_delta: float) -> void:
	dynamic_entity.move_fsm.update_anim_vector()
