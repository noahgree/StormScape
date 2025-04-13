@tool
extends Enemy
class_name BasicZombie

@export var enabled: bool = true


func _ready() -> void:
	super._ready()
	if not enabled:
		fsm.states = [IdleState.new(), DieState.new()]
