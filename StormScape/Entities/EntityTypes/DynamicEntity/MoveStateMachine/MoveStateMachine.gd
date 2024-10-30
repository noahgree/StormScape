extends StateMachine
class_name MoveStateMachine
## FSM class for dynamic entities that implements the managing logic of transitioning between movement states.

@export var entity: DynamicEntity ## The entity that this FSM moves.
@export var anim_tree: AnimationTree ## The animation tree node to support the children state animations.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var _sprint_stamina_usage: float = 15.0 ## The amount of stamina used per second when the entity is sprinting.
@export_custom(PROPERTY_HINT_NONE, "suffix:per dash") var _dash_stamina_usage: float = 20.0 ## The amount of stamina used per dash activation.
@export var _friction: float = 1550 ## The decrease in speed per second for the entity.
@export var _confusion_amount: float = 0 ## The amount of influence to apply to the velocity to simulate confusion.

@onready var dash_cooldown_timer: Timer = $Dash/DashCooldownTimer ## The timer controlling the minimum time between activating dashes.
@onready var stunned_timer: Timer = $Stunned/StunnedTimer ## The timer controlling how long the stun effect has remaining.

var anim_vector: Vector2 = Vector2.ZERO ## The vector to provide the associated animation state machine with.
var knockback_vector: Vector2 = Vector2.ZERO ## The current knockback to apply to any state that can move.
var can_receive_effects: bool = true ## Whether the entity is in a state that can receive effects.
const MAX_KNOCKBACK: int = 3000 ## The highest length the knockback vector can ever be to prevent dramatic movement.


## Asserts the necessary components exist to support a dynamic entity, then caches the child states and sets them up.
## Overrides the parent state machine class _ready function.
func _ready() -> void:
	assert(has_node("Idle"), "Dynamic entities must have an Idle state in the move state machine.")
	assert(has_node("Stunned"), "Dynamic entities must have a Stunned state in the move state machine.")
	
	for child in get_children():
		if child is MoveState:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(_on_child_transition)
			child.dynamic_entity = entity
			child.stamina_component = entity.get_node("StaminaComponent")
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state
		
	var moddable_stats: Dictionary = {
		"sprint_stamina_usage" : _sprint_stamina_usage, "dash_stamina_usage" : _dash_stamina_usage,
		"friction" : _friction, "confusion_amount" : _confusion_amount
	}
	entity.stats.add_moddable_stats(moddable_stats)

## Checks if knockback needs to be lerped to 0 and passes the physics process to the active state.
## Advances animation tree manually so that it respects time snares. Overrides parent state machine class.
func state_machine_physics_process(delta: float) -> void:
	if knockback_vector.length() > 100:
		knockback_vector = lerp(knockback_vector, Vector2.ZERO, 0.1)
	else:
		knockback_vector = Vector2.ZERO
	
	if current_state:
		current_state.state_physics_process(delta)
		anim_tree.advance(delta)

## Assists in turning the character to the right direction upon game loads.
func verify_anim_vector() -> void:
	if current_state and current_state.has_method("_animate"):
		current_state._animate()

## Requests to transition to the stun state, doing so if possible.
func request_stun(duration: float) -> void:
	if current_state:
		stunned_timer.wait_time = duration
		_on_child_transition(current_state, "Stunned")

## Requests to add a value to the current knockback vector, doing so if possible.
func request_knockback(knockback: Vector2) -> void:
	knockback_vector = (knockback_vector + knockback).limit_length(MAX_KNOCKBACK)

func spawn() -> void:
	if current_state:
		_on_child_transition(current_state, "Spawn")

func die() -> void:
	if current_state:
		_on_child_transition(current_state, "Die")
