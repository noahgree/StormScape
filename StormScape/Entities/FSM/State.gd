@icon("res://Utilities/Debug/EditorIcons/state.svg")
extends Node
class_name State
## Generic state class intended to be subclassed by specific states like idle and move.


@warning_ignore("unused_signal")
signal Transitioned

@export var anim_tree: AnimationTree

var parent: DynamicEntity
var stamina_component: StaminaComponent

@onready var state_machine = get_parent()


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
