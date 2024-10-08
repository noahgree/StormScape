extends Node
class_name State
"""
Generic state class intended to be subclasses by specific states.
"""

signal Transitioned

var parent: DynamicEntity
var stamina_component: StaminaComponent

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
