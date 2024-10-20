@icon("res://Utilities/Debug/EditorIcons/state_machine.svg")
extends StateMachine
class_name MoveStateMachine
## FSM class for dynamic entities that implements the managing logic of transitioning and maintaining states.
## 
## No nodes except for this FSM node and its children should *EVER* know what state is active. 

@export var anim_tree: AnimationTree ## The animation tree node to support the children state animations.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var sprint_stamina_usage: float = 15.0 ## The amount of stamina used per second when the entity is sprinting.
@export_custom(PROPERTY_HINT_NONE, "suffix:per dash") var dash_stamina_usage: float = 20.0 ## The amount of stamina used per dash activation.
@export var friction: float = 1550 ## The decrease in speed per second for the entity.

@onready var dash_cooldown_timer: Timer = %DashCooldownTimer ## The minimum time between activating a dash.

var anim_vector: Vector2 = Vector2.ZERO ## The vector to provide the associated animation state machine with.
var stun_time: float ## Set by whatever requests this state machine to enter the stun state each time.
var knockback_vector: Vector2 = Vector2.ZERO ## The current knockback to apply to any state that can move.


## Asserts the necessary components exist to support a dynamic entity, then caches the child states and sets them up.
func _ready() -> void:
	var parent: DynamicEntity = get_parent()
	assert(has_node("Idle"), "Dynamic entities must have an Idle state.")
	assert(has_node("Stunned"), "Dynamic entities must have a Stunned state.")
	
	var stamina_component: StaminaComponent = parent.get_node("StaminaComponent")
	
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(_on_child_transition)
			child.dynamic_entity = parent
			child.stamina_component = parent.get_node("StaminaComponent")
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

## Checks if knockback needs to be lerped to 0 and passes the physics process to the active state.
func state_machine_physics_process(delta: float) -> void:
	if knockback_vector.length() > 100:
		knockback_vector = lerp(knockback_vector, Vector2.ZERO, 0.1)
	else:
		knockback_vector = Vector2.ZERO
	
	if current_state:
		current_state.state_physics_process(delta)

## Requests to transition to the stun state, doing so if possible.
func request_stun(duration: float) -> void:
	if current_state:
		stun_time = duration
		_on_child_transition(current_state, "Stunned")

## Requests to add a value to the current knockback vector, doing so if possible.
func request_knockback(knockback: Vector2) -> void:
	knockback_vector += knockback
