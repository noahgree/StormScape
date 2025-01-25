extends Node
class_name Controller
## This is a base class for what should be implemented on a per-entity basis. This receives signals from states in a FSM
## and decides what state to transition to.

@onready var fsm: StateMachine = get_parent()

var can_receive_effects: bool = true ## Whether the entity is in a state that can receive effects.
var last_anim_vector: Vector2 = Vector2.ZERO ## The anim_vector updated during the last frame. Used to make lerping work.


#region Inputs
func controller_handle_input(event: InputEvent) -> void:
	if fsm.current_state:
		fsm.current_state.state_handle_input(event)
#endregion

#region Core
func controller_process(delta: float) -> void:
	if fsm.current_state:
		fsm.current_state.state_process(delta)

func controller_physics_process(delta: float) -> void:
	if fsm.current_state:
		fsm.current_state.state_physics_process(delta)

		fsm.get_parent().anim_tree.advance(delta)
#endregion

## Assists in turning the character to the right direction upon game loads.
func verify_anim_vector() -> void:
	if fsm.current_state and fsm.current_state.has_method("_animate"):
		fsm.current_state._animate()

## Called when the entity spawns.
func spawn() -> void:
	fsm.change_state("Spawn")

## Called when the entity dies.
func die() -> void:
	fsm.change_state("Die")
