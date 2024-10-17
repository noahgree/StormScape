@icon("res://Utilities/Debug/EditorIcons/state_machine.svg")
extends Node
class_name CharStateMachine
## FSM class for moving entities that implements the managing logic of transitioning and maintaining states.
## 
## No nodes except for this FSM node and its children should *EVER* know what state is active. 
## By allowing this, you allow a long rabbit hole of dependencies that make things less and less reusable.


@export var initial_state: State ## What state the state machine should start off in.
@export var anim_tree: AnimationTree ## The animation tree node to support the children state animations.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var sprint_stamina_usage: float = 15.0 ## The amount of stamina used per second when the entity is sprinting.
@export_custom(PROPERTY_HINT_NONE, "suffix:per dash") var dash_stamina_usage: float = 20.0 ## The amount of stamina used per dash activation.

@onready var dash_cooldown_timer: Timer = %DashCooldownTimer ## The minimum time between activating a dash.

var current_state: State ## The current state the state machine is in.
var states: Dictionary = {} ## A dict of all current children states of the state machine node.
var anim_pos: Vector2 = Vector2.ZERO ## The vector to provide the associated animation state machine with.

## Called externally by the parent node of this FSM. This passes in the parent reference to each child state.
## Parent entities must have an appropriately named and typed StaminaComponent or execution will fail.
func init(parent: DynamicEntity) -> void:
	var stamina_component
	if parent.has_node("StaminaComponent"):
		stamina_component = parent.get_node("StaminaComponent")
	assert(stamina_component is StaminaComponent, "Parent entities of this FSM must have a StaminaComponent to support being a dynamic entity.")
	
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.Transitioned.connect(on_child_transition)
			child.parent = parent
			child.stamina_component = parent.get_node("StaminaComponent")

func _ready() -> void:
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func state_machine_process(delta: float) -> void:
	if current_state:
		current_state.state_process(delta)

func state_machine_physics_process(delta: float) -> void:
	if current_state:
		current_state.state_physics_process(delta)

func state_machine_handle_input(event: InputEvent) -> void:
	if current_state:
		current_state.state_handle_input(event)

func on_child_transition(requesting_state, new_state_name) -> void:
	if requesting_state != current_state:
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
	
	if DebugFlags.PrintFlags.char_state_machine_swaps:
		print_rich("DEBUG: Character entered [color=pink]" + current_state.name.to_lower() + "[/color]")
