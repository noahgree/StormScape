@icon("res://Utilities/Debug/EditorIcons/state_machine.svg")
extends Node
class_name StateMachine
## Base FSM class that implements the managing logic of transitioning and maintaining states.
##
## No nodes except for this FSM node and its children should *EVER* know what state is active.

@export var states: Array[State] ## The possible states this fsm has, with index 0 being the initial state on ready.
@export_subgroup("Debug")
@export var print_state_changes: bool = false ## When true and the DebugFlag flag is also true, this state machine will print when its state gets changed.

@onready var controller: Controller = $Controller ## The controller that controls the actions of the parent entity.

var current_state: State: set = _set_state ## The current state the state machine is in.
var state_indices: Dictionary[StringName, int] = {} ## Maps state names to the index they are within the state array.


## Caches the child states and sets them up, then enters the initial state.
func _ready() -> void:
	if not get_parent().is_node_ready():
		await get_parent().ready
	controller.entity = get_parent()
	controller.fsm = self
	controller.setup()

	make_states_unique()

	var i: int = 0
	for state: State in states:
		state.initialize(self, controller, get_parent())
		state_indices[state.state_id] = i
		i += 1
	states[0].enter()
	current_state = states[0]

## Makes the states scene-unique by creating a new instance of the array itself and everything in it on ready.
func make_states_unique() -> void:
	var new_array: Array[State]
	for state: State in states:
		new_array.append(state.duplicate())
	states = new_array

## Setter for the state variable. Prints debug output according to a flag in the debug flags.
func _set_state(new_state: State) -> void:
	if DebugFlags.state_machine_swaps and print_state_changes:
		print_rich("[i][u]" + get_parent().name + "[/u] [/i]entered [color=pink][b]" + new_state.state_id + "[/b][/color] (was " + (str(current_state.state_id) if current_state else "null") + ")")
	current_state = new_state

## Checks for the existence of the new state and then switches to it.
func change_state(new_state_id: StringName) -> void:
	var new_state_index_in_array: int = state_indices.get(new_state_id, -1)
	if new_state_index_in_array != -1:
		var new_state: State = states[new_state_index_in_array]
		current_state.exit()
		new_state.enter()
		current_state = new_state
	elif DebugFlags.state_machine_swaps:
		push_warning(owner.name + " tried to switch to a non-existent state (" + new_state_id + ")")

## Checks if the state exists in this FSM.
func has_state(state_id: StringName) -> bool:
	return state_indices.has(state_id)
