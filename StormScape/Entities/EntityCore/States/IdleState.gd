extends State
class_name IdleState
## Handles when the dynamic entity is not moving.


func enter() -> void:
	entity.facing_component.travel_anim_tree("idle")

func exit() -> void:
	pass

## If any input vector besides Vector2.ZERO is detected, we transition to the run state
func state_physics_process(_delta: float) -> void:
	_animate()
	_do_entity_idle()

func _do_entity_idle() -> void:
	if controller.get_movement_vector() != Vector2.ZERO:
		controller.notify_started_moving()
	else:
		entity.velocity = Vector2.ZERO

func _animate() -> void:
	entity.facing_component.update_blend_position("idle")
