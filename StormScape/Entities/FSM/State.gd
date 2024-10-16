@icon("res://Utilities/Debug/EditorIcons/state.svg")
extends Node
class_name State
## Generic state class intended to be subclassed by specific states like idle and move.

@warning_ignore("unused_signal")
signal Transitioned ## Called by a subclassed state when it wants to transition to another state.

var parent: DynamicEntity ## The dynamic entity which contains the FSM that this state is a part of.
var stamina_component: StaminaComponent ## The stamina component for the dynamic entity referenced by parent.

@onready var state_machine = get_parent() ## The FSM that controls this state.


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
