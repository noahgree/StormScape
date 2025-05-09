extends Node2D
class_name Controller
## This is a base class for what should be implemented on a per-entity basis. This receives
## signals from states in a FSM and decides what state to transition to.

var entity: DynamicEntity ## The entity that this controller operates on.
var fsm: StateMachine ## The FSM that this controller works with.
var can_receive_effect_srcs: bool = true ## Whether the entity is in a state that can receive effect sources.


#region Core
func setup() -> void:
	pass

func controller_process(delta: float) -> void:
	if fsm.current_state:
		fsm.current_state.state_process(delta)

func controller_physics_process(delta: float) -> void:
	if fsm.current_state:
		fsm.current_state.state_physics_process(delta)

		fsm.get_parent().anim_tree.advance(delta)
#endregion

## Assists in turning the character to the right direction upon game loads.
func update_animation() -> void:
	if fsm.current_state:
		fsm.current_state._animate()

## Called when the entity spawns.
func spawn() -> void:
	fsm.change_state("spawn")

## Called when the entity dies.
func die() -> void:
	fsm.change_state("die")
