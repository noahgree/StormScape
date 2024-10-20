extends State
## Handles when the character is not moving.

var movement_vector: Vector2 = Vector2.ZERO


func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("idle")
	_animate()

func exit() -> void:
	pass

## If any input vector besides Vector2.ZERO is detected, we transition to the run state
func state_physics_process(delta: float) -> void:
	movement_vector = _calculate_move_vector()
	var knockback: Vector2 = fsm.knockback_vector
	
	if movement_vector != Vector2.ZERO:
		Transitioned.emit(self, "Run")
	else:
		if knockback > Vector2.ZERO:
			dynamic_entity.velocity = knockback
			Transitioned.emit(self, "Run")
		else:
			dynamic_entity.velocity = Vector2.ZERO

func _calculate_move_vector() -> Vector2:
	return _get_input_vector()

func _animate() -> void:
	fsm.anim_tree.set("parameters/idle/blendspace2d/blend_position", fsm.anim_vector)
