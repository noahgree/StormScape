@icon("res://Utilities/Debug/EditorIcons/state.svg")
extends Resource
class_name State
## Generic state class intended to be subclassed by individual states.

var state_id: StringName ## The ID of this state, used by the FSM to cache the states. Set this in _init().
var fsm: StateMachine ## The finite state machine controlling this state.
var controller: Controller ## The controller that controls the entity's actions.
var entity: PhysicsBody2D ## The entity which contains the FSM that this state is a part of.


## Sets up the state with its needed info. Called by the FSM.
func initialize(state_machine: StateMachine, entity_controller: Controller, source_entity: PhysicsBody2D) -> void:
	fsm = state_machine
	controller = entity_controller
	entity = source_entity

## Called as soon as the state is entered.
func enter() -> void:
	pass

## Called just before the state is exited.
func exit() -> void:
	pass

## Called to manually tick the process of the state since it is only a resource.
func state_process(_delta: float) -> void:
	pass

## Called to manually tick the physics process of the state since it is only a resource.
func state_physics_process(_delta: float) -> void:
	pass

## Called to animate during the state.
func _animate() -> void:
	pass
