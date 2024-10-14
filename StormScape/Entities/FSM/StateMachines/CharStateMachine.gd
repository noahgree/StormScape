extends Node
class_name CharStateMachine
## FSM class for moving entities that implements the managing logic of transitioning and maintaining states.
## 
## No nodes except for this FSM node and its children should *EVER* know what state is active. 
## By allowing this, you allow a long rabbit hole of dependencies that make things less and less reusable.


@export var initial_state: State

var current_state: State
var states: Dictionary = {}
var anim_pos: Vector2

func init(parent: DynamicEntity) -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(on_child_transition)
			child.parent = parent
			if parent.has_node("StaminaComponent"):
				child.stamina_component = parent.get_node("StaminaComponent")


func _ready() -> void:
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

func on_child_transition(requesting_state, new_state_name) -> void:
	if requesting_state != current_state:
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
	
	if DebugFlags.PrintFlags.char_state_machine_swaps:
		print("DEBUG: Character entered the state \"" + current_state.name.to_lower() + "\"")
