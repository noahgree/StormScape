extends StateMachine
class_name ActionStateMachine
## FSM class for dynamic entities that implements the managing logic of transitioning between action states.

@export var entity: DynamicEntity ## The entity that this FSM maintains the actions for.


## Asserts the necessary components exist to support a dynamic entity, then caches the child states and sets them up.
## Overrides parent state machine class.
func _ready() -> void:
	assert(has_node("ActionIdle"), "Dynamic entities must have an Idle state in the action state machine.")
	assert(get_parent().hands, get_parent().name + " has an action FSM but does not have a hands component.")

	for child in get_children():
		if child is ActionState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transition)
			child.dynamic_entity = entity
			child.stamina_component = entity.get_node("StaminaComponent")

	if initial_state:
		initial_state.enter()
		current_state = initial_state

## Overrides parent state machine class.
func state_machine_physics_process(delta: float) -> void:
	if current_state:
		current_state.state_physics_process(delta)
