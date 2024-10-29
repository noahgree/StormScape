extends Node
class_name StateMachine
## Base FSM class that implements the managing logic of transitioning and maintaining states.
## 
## No nodes except for this FSM node and its children should *EVER* know what state is active. 

@export var initial_state: State ## What state the state machine should start off in.


var current_state: State: ## The current state the state machine is in.
	set(new_state):
		current_state = new_state
		if DebugFlags.PrintFlags.state_machine_swaps:
			print_rich("DEBUG: " + get_parent().name + " entered [color=pink]" + current_state.name.to_lower() + "[/color]")
var states: Dictionary = {} ## A dict of all current children states of the state machine node.

## Caches the child states and sets them up.
func _ready() -> void:
	var parent = get_parent()
	
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(_on_child_transition)
			child.dynamic_entity = parent
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func state_machine_process(delta: float) -> void:
	if current_state:
		current_state.state_process(delta)

func state_machine_physics_process(delta: float) -> void:
	if current_state:
		current_state.state_physics_process(delta)

func state_machine_handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.state_handle_input(event)

func _on_child_transition(requesting_state, new_state_name) -> void:
	if requesting_state != current_state:
		return
	
	var new_state: State = states.get(new_state_name.to_lower())
	if new_state:
		if current_state:
			current_state.exit()
			
			new_state.enter()
			current_state = new_state
