extends StateMachine
class_name MoveStateMachine
## FSM class for dynamic entities that implements the managing logic of transitioning between movement states.

@export var entity: DynamicEntity ## The entity that this FSM moves.
@export var anim_tree: AnimationTree ## The animation tree node to support the children state animations.
@export var footstep_texture: Texture2D ## The footstep texture used to leave a trail behind.
@export var footstreak_offsets: Array[Vector2] = [Vector2(-4, 0), Vector2(4, 0)] ## The offsets to draw the footstreaks at when hit by knockback.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var _sprint_stamina_usage: float = 15.0 ## The amount of stamina used per second when the entity is sprinting.
@export_custom(PROPERTY_HINT_NONE, "suffix:per dash") var _dash_stamina_usage: float = 20.0 ## The amount of stamina used per dash activation.
@export var _friction: float = 1550 ## The decrease in speed per second for the entity.
@export var _confusion_amount: float = 0 ## The amount of influence to apply to the velocity to simulate confusion.

@onready var dash_cooldown_timer: Timer = $Dash/DashCooldownTimer ## The timer controlling the minimum time between activating dashes.
@onready var stunned_timer: Timer = $Stunned/StunnedTimer ## The timer controlling how long the stun effect has remaining.

var anim_vector: Vector2 = Vector2.ZERO ## The vector to provide the associated animation state machine with.
var curr_mouse_direction: Vector2 = Vector2.ZERO
var knockback_vector: Vector2 = Vector2.ZERO ## The current knockback to apply to any state that can move.
var knockback_streak_nodes: Array[FootStreak] = [] ## The current foot streak in the ground from knockback.
var can_receive_effects: bool = true ## Whether the entity is in a state that can receive effects.
var should_rotate: bool = true ## Reflects whether or not we are performing an action that prevents us from changing the current anim vector used by child states to rotate the entity animation.
var rotation_lerping_factor: float = 0.1 ## The current lerping rate for getting the current mouse direction.
const MAX_KNOCKBACK: int = 3000 ## The highest length the knockback vector can ever be to prevent dramatic movement.
const DEFAULT_ROTATION_LERPING_FACTOR: float = 0.1 ## The default lerping rate for getting the current mouse direction.


## Asserts the necessary components exist to support a dynamic entity, then caches the child states and sets them up.
## Overrides the parent state machine class _ready function.
func _ready() -> void:
	assert(has_node("Idle"), "Dynamic entities must have an Idle state in the move state machine.")
	assert(has_node("Stunned"), "Dynamic entities must have a Stunned state in the move state machine.")

	rotation_lerping_factor = DEFAULT_ROTATION_LERPING_FACTOR

	for child: Node in get_children():
		if child is MoveState:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transition)
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
	if should_rotate:
		update_anim_vector()

	if knockback_vector.length() > 100:
		update_knockback_streak()
		knockback_vector = lerp(knockback_vector, Vector2.ZERO, 6 * delta)
	else:
		knockback_vector = Vector2.ZERO

	if current_state:
		current_state.state_physics_process(delta)
		anim_tree.advance(delta)

## Updates the current animation vector by lerping the current mouse direction.
func update_anim_vector() -> void:
	var entity_loc_with_sprite_offset: Vector2 = entity.sprite.position / 2.0 + entity.global_position
	curr_mouse_direction = get_lerped_mouse_direction_to_pos(curr_mouse_direction, entity_loc_with_sprite_offset)
	anim_vector = curr_mouse_direction

## Takes in a current direction of rotation and a target position to face, lerping it every frame.
func get_lerped_mouse_direction_to_pos(current_direction: Vector2, target_position: Vector2) -> Vector2:
	var target_direction: Vector2 = (entity.get_global_mouse_position() - target_position).normalized()

	var current_angle: float = current_direction.angle()
	var target_angle: float = target_direction.angle()

	var angle_diff: float = angle_difference(current_angle, target_angle)

	var new_angle: float = current_angle + angle_diff * rotation_lerping_factor

	return Vector2.RIGHT.rotated(new_angle)

func get_mouse_direction_to_pos() -> Vector2:
	var entity_loc_with_sprite_offset: Vector2 = entity.sprite.position / 2.0 + entity.global_position
	return (entity.get_global_mouse_position() - entity_loc_with_sprite_offset).normalized()

## Assists in turning the character to the right direction upon game loads.
func verify_anim_vector() -> void:
	if current_state and current_state.has_method("_animate"):
		current_state._animate()

func create_footprint(offsets: Array) -> void:
	for offset: Vector2 in offsets:
		var trans: Transform2D = Transform2D(atan2(anim_vector.y, anim_vector.x), get_parent().global_position + offset)
		var footprint: SpriteGhost = SpriteGhost.create(trans, Vector2(0.8, 0.8), footstep_texture, 3.0)
		footprint.z_index = get_parent().sprite.z_index - 1
		footprint.material.set_shader_parameter("tint_color", Color(0.0, 0.0, 0.0, 0.8))
		GlobalData.world_root.add_child(footprint)

## Requests to transition to the stun state, doing so if possible.
func request_stun(duration: float) -> void:
	if current_state:
		stunned_timer.wait_time = duration
		_on_child_transition(current_state, "Stunned")

## Requests to add a value to the current knockback vector, doing so if possible.
func request_knockback(knockback: Vector2) -> void:
	knockback_vector = (knockback_vector + knockback).limit_length(MAX_KNOCKBACK)
	if knockback_streak_nodes.is_empty() or (not is_instance_valid(knockback_streak_nodes[0])) or (knockback_streak_nodes[0] == null) or (knockback_streak_nodes[0].is_fading):
		knockback_streak_nodes.clear()
		for offset: Vector2 in footstreak_offsets:
			var streak: FootStreak = FootStreak.create()
			knockback_streak_nodes.append(streak)
			GlobalData.world_root.add_child(streak)

func update_knockback_streak() -> void:

	for i: int in range(footstreak_offsets.size()):
		if knockback_streak_nodes.size() >= (i + 1) and is_instance_valid(knockback_streak_nodes[i]) and knockback_streak_nodes[i] != null:
			knockback_streak_nodes[i].update_trail_position(entity.global_position + footstreak_offsets[i], atan2(anim_vector.y, anim_vector.x))
		else:
			knockback_streak_nodes.clear()

## Called when the entity spawns.
func spawn() -> void:
	if current_state:
		_on_child_transition(current_state, "Spawn")

## Called when the entity dies.
func die() -> void:
	if current_state:
		_on_child_transition(current_state, "Die")
