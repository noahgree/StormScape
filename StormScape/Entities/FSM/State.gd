@icon("res://Utilities/Debug/EditorIcons/state.svg")
extends Node
class_name State
## Generic state class intended to be subclassed by individual states.

@warning_ignore("unused_signal")
signal transitioned ## Called by a subclassed state when it wants to transition to another state.

@onready var fsm: MoveStateMachine = get_parent() ## The finite state machine controlling this state.

var entity: PhysicsBody2D ## The entity which contains the FSM that this state is a part of.


func enter() -> void:
	pass

func exit() -> void:
	pass

func state_process(_delta: float) -> void:
	pass

func state_physics_process(_delta: float) -> void:
	pass

func state_handle_input(_event: InputEvent) -> void:
	pass

## The default is to get user key input, but this should be overridden by subclass states to determine how to move.
func _get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

## The default is to get user key input, but this should be overridden by subclass states to determine when to dash.
func _is_dash_requested() -> bool:
	return Input.is_action_pressed("dash")

## The default is to get user key input, but this should be overridden by subclass states to determine when to sneak.
func _is_sneak_requested() -> bool:
	return Input.is_action_pressed("sneak")
