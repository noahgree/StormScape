extends State
class_name DynamicState
## State class intended to be subclassed by specific dynamic states like idle and move.

var dynamic_entity: DynamicEntity ## The dynamic entity which contains the FSM that this state is a part of.
var stamina_component: StaminaComponent ## The stamina component for the dynamic entity referenced by parent.


func _get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

func _is_dash_requested() -> bool:
	return Input.is_action_pressed("dash")
