extends State
class_name MoveState
## State class intended to be subclassed by specific dynamic states like idle and move.

@onready var fsm: MoveStateMachine = get_parent()

var dynamic_entity: DynamicEntity ## The dynamic entity which contains the FSM that this state is a part of.
var stamina_component: StaminaComponent ## The stamina component for the dynamic entity.


## The default is to get user key input, but this should be overridden by subclass states to determine how to move.
func _get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

## The default is to get user key input, but this should be overridden by subclass states to determine when to dash.
func _is_dash_requested() -> bool:
	return Input.is_action_pressed("dash")

## The default is to get user key input, but this should be overridden by subclass states to determine when to sneak.
func _is_sneak_requested() -> bool:
	return Input.is_action_pressed("sneak")
