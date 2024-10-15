extends State
## Handles when the character is not moving.


var movement_vector: Vector2 = Vector2.ZERO


func enter() -> void:
	anim_tree["parameters/playback"].travel("idle")
	animate()

func exit() -> void:
	pass

func state_physics_process(_delta: float) -> void:
	movement_vector = calculate_move_vector()
	
	if movement_vector != Vector2.ZERO:
		Transitioned.emit(self, "Run")
	else:
		parent.velocity = Vector2.ZERO

func calculate_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

func animate() -> void:
	anim_tree.set("parameters/idle/blendspace2d/blend_position", state_machine.anim_pos)
