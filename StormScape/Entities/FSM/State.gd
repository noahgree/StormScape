@icon("res://Utilities/Debug/EditorIcons/state.svg")
extends Node
class_name State
## Generic state class intended to be subclassed by individual states.

@onready var controller: Controller = get_parent().get_node("Controller")

var fsm: StateMachine ## The finite state machine controlling this state.
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
