@icon("res://Utilities/Debug/EditorIcons/state_machine.svg")
extends Node
class_name StateMachine
## Base FSM class that implements the managing logic of transitioning and maintaining states.
##
## No nodes except for this FSM node and its children should *EVER* know what state is active.

@export var initial_state: State ## What state the state machine should start off in.
@export var print_state_changes: bool = false ## When true and the DebugFlag flag is also true, this state machine will print when its state gets changed.

@onready var controller: Controller = $Controller

var current_state: State: ## The current state the state machine is in.
	set(new_state):
		current_state = new_state
		if DebugFlags.PrintFlags.state_machine_swaps and print_state_changes:
			print_rich("[i]" + get_parent().name + " [/i]entered [color=pink][b]" + current_state.name.to_lower() + "[/b][/color]")
var states: Dictionary[StringName, State] = {} ## A dict of all current children states of the state machine node.


## Caches the child states and sets them up.
func _ready() -> void:
	if not get_parent().is_node_ready():
		await get_parent().ready

	for child: Node in get_children():
		if child is State:
			states[StringName(child.name.to_lower())] = child
			child.fsm = self
			child.entity = owner

	if initial_state:
		initial_state.enter()
		current_state = initial_state

## Checks for the existence of the new state and then switches to it.
func change_state(new_state_name: String) -> void:
	var new_state: State = states.get(StringName(new_state_name.to_lower()))
	if new_state:
		if current_state:
			current_state.exit()

			new_state.enter()
			current_state = new_state
	else:
		push_error(owner.name + " tried to switch to a non-existent state (" + new_state_name + ") within their FSM.")
