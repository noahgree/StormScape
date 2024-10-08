extends State


func enter() -> void:
	pass

func exit() -> void:
	pass

func state_physics_process(_delta: float) -> void:
	if get_input_vector() != Vector2.ZERO:
		Transitioned.emit(self, "Move")
	else:
		parent.velocity = Vector2.ZERO

func get_input_vector() -> Vector2:
	var input = Vector2.ZERO
	input.x = int(Input.is_action_pressed("d")) - int(Input.is_action_pressed("a"))
	input.y = int(Input.is_action_pressed("s")) - int(Input.is_action_pressed("w"))
	return input.normalized()
