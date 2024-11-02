@icon("res://Utilities/Debug/EditorIcons/state.svg")
extends Node
class_name State
## Generic state class intended to be subclassed by state categories like DynamicState.

@warning_ignore("unused_signal")
signal transitioned ## Called by a subclassed state when it wants to transition to another state.


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
