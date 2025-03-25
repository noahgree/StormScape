extends Controller
class_name DynamicController
## FSM Controller designed to work with dynamic entities.

@export var entity: DynamicEntity ## The entity that this FSM moves.
@export var footstep_texture: Texture2D ## The footstep texture used to leave a trail behind.
@export var footstreak_offsets: Array[Vector2] = [Vector2(-4, 0), Vector2(4, 0)] ## The offsets to draw the footstreaks at when hit by knockback.
@export var MAX_KNOCKBACK: int = 3000 ## The highest length the knockback vector can ever be to prevent dramatic movement.

#region Stats
@export_group("Run & Sprint")
@export var _max_speed: float = 150 ## The maximum speed the entity can travel once fully accelerated.
@export var _acceleration: float = 1250 ## The increase in speed per second for the entity.
@export var _friction: float = 1550 ## The decrease in speed per second for the entity.
@export var _sprint_multiplier: float = 1.5 ## How much faster the max_speed should be when sprinting.
@export var _run_collision_impulse_factor: float = 1.0 ## A multiplier that controls how much impulse gets applied to rigid entites when colliding with them during the run state.
@export_custom(PROPERTY_HINT_NONE, "suffix:per second") var _sprint_stamina_usage: float = 15.0 ## The amount of stamina used per second when the entity is sprinting.

@export_group("Sneak")
@export var _max_stealth: int = 50 ## The percent to shrink the detection radius by when sneaking.
@export var _max_sneak_speed: int = 50 ## How fast you can move while sneaking.
@export var _sneak_acceleration: float = 500 ## The increase in speed per second for the entity while sneaking.
@export var _sneak_collision_impulse_factor: float = 1.0 ## A multiplier that controls how much impulse gets applied to rigid entites when colliding with them during the run state.

@export_group("Dash")
@export var _dash_speed: float = 1000 ## How fast the dash moves the character.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _dash_duration: float = 0.08 ## The dash duration.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _dash_cooldown: float = 1.0 ## The dash cooldown.
@export_custom(PROPERTY_HINT_NONE, "suffix:per dash") var _dash_stamina_usage: float = 20.0 ## The amount of stamina used per dash activation.
@export var _dash_collision_impulse_factor: float = 1.0 ## A multiplier that controls how much impulse gets applied to rigid entites when colliding with them during a dash.
#endregion

var dash_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_dash_timer_timeout)
var dash_cooldown_timer: Timer = TimerHelpers.create_one_shot_timer(self) ## The timer controlling the minimum time between activating dashes.
var stunned_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_stun_timer_timeout) ## The timer controlling how long the stun effect has remaining.
var knockback_vector: Vector2 = Vector2.ZERO ## The current knockback to apply to any state that can move.
var knockback_streak_nodes: Array[FootStreak] = [] ## The current foot streak in the ground from knockback.


## Asserts the necessary components exist to support a dynamic entity, then caches the child
## states and sets them up.
func _ready() -> void:
	assert(fsm.has_node("Idle"), "Dynamic entities must have an Idle state in the FSM. Add one to " + owner.name + ".")
	assert(fsm.has_node("Stunned"), "Dynamic entities must have a Stunned state in the FSM. Add one to " + owner.name + ".")

	var moddable_stats: Dictionary[StringName, float] = {
		&"max_speed" : _max_speed,
		&"acceleration" : _acceleration,
		&"sprint_stamina_usage" : _sprint_stamina_usage,
		&"sprint_multiplier" : _sprint_multiplier,
		&"run_collision_impulse_factor" : _run_collision_impulse_factor,
		&"friction" : _friction,
		&"confusion_amount" : 0.0,
		&"max_stealth" : _max_stealth,
		&"max_sneak_speed" : _max_sneak_speed,
		&"sneak_acceleration" : _sneak_acceleration,
		&"sneak_collision_impulse_factor" : _sneak_collision_impulse_factor,
		&"dash_speed" : _dash_speed,
		&"dash_duration" : _dash_duration,
		&"dash_stamina_usage" : _dash_stamina_usage,
		&"dash_cooldown" : _dash_cooldown,
		&"dash_collision_impulse_factor" : _dash_collision_impulse_factor
	}
	entity.stats.add_moddable_stats(moddable_stats)

#region Inputs
func get_movement_vector() -> Vector2:
	return (Vector2.ZERO.rotated(entity.stats.get_stat("confusion_amount")))

func get_should_sprint() -> bool:
	return false

func get_should_sneak() -> bool:
	return false
#endregion

#region Core
## Checks if knockback needs to be lerped to 0 and passes the physics process to the active state.
## Advances animation tree manually so that it respects time snares. Overrides parent state machine class.
func controller_physics_process(delta: float) -> void:
	super.controller_physics_process(delta)

	if knockback_vector.length() > 100:
		update_knockback_streak()
		knockback_vector = lerp(knockback_vector, Vector2.ZERO, 6 * delta)
	else:
		knockback_vector = Vector2.ZERO
#endregion

#region Footprints & Streaks
func create_footprint(offsets: Array) -> void:
	var facing_dir: Vector2 = entity.facing_component.facing_dir

	for offset: Vector2 in offsets:
		var trans: Transform2D = Transform2D(atan2(facing_dir.y, facing_dir.x), entity.global_position + offset)
		var footprint: SpriteGhost = SpriteGhost.create(trans, Vector2(0.8, 0.8), footstep_texture, 3.0)

		footprint.z_index = 0
		footprint.set_instance_shader_parameter("tint_color", Color(0.0, 0.0, 0.0, 0.8))

		Globals.world_root.add_child(footprint)

## Updates the knockback streak points array that determines how the streak line is drawn.
func update_knockback_streak() -> void:
	var facing_dir: Vector2 = entity.facing_component.facing_dir

	for i: int in range(footstreak_offsets.size()):
		if (knockback_streak_nodes.size() >= (i + 1)) and is_instance_valid(knockback_streak_nodes[i]) and knockback_streak_nodes[i] != null:
			knockback_streak_nodes[i].update_trail_position(
				entity.global_position + footstreak_offsets[i], atan2(facing_dir.y, facing_dir.x)
				)
		else:
			knockback_streak_nodes.clear()

func reset_and_create_knockback_streak() -> void:
	if knockback_streak_nodes.is_empty() or (not is_instance_valid(knockback_streak_nodes[0])) or (knockback_streak_nodes[0] == null) or (knockback_streak_nodes[0].is_fading):
		knockback_streak_nodes.clear()

		for offset: Vector2 in footstreak_offsets:
			var streak: FootStreak = FootStreak.create()
			knockback_streak_nodes.append(streak)

			Globals.world_root.add_child(streak)
#endregion

#region States
func notify_stopped_moving() -> void:
	match fsm.current_state.name:
		"Run", "Sneak", "Dash", "Stunned", "Spawn":
			fsm.change_state("Idle")

## Requests to add a value to the current knockback vector, doing so if possible.
func notify_requested_knockback(knockback: Vector2) -> void:
	match fsm.current_state.name:
		"Run", "Sneak", "Idle", "Stunned":
			knockback_vector = (knockback_vector + knockback).limit_length(MAX_KNOCKBACK)
			fsm.change_state("Run")
			reset_and_create_knockback_streak()

## When the stun timer ends, notify that we can return to Idle if needed.
func _on_stun_timer_timeout() -> void:
	notify_stopped_moving()

## When the dash timer ends, notify that we can return to Idle if needed.
func _on_dash_timer_timeout() -> void:
	notify_stopped_moving()

func notify_spawn_ended() -> void:
	match fsm.current_state.name:
		"Spawn":
			fsm.change_state("Idle")

func notify_requested_stun(duration: float) -> void:
	match fsm.current_state.name:
		"Run", "Idle", "Stunned", "Sneak":
			stunned_timer.wait_time = duration
			fsm.change_state("Stunned")
			stunned_timer.start()

func notify_requested_dash() -> void:
	match fsm.current_state.name:
		"Run", "Sneak":
			if get_movement_vector().length() == 0:
				return

			var dash_stamina_usage: float = entity.stats.get_stat("dash_stamina_usage")
			if fsm.dash_cooldown_timer.is_stopped() and entity.stamina_component.use_stamina(dash_stamina_usage):
				fsm.change_state("Dash")

func notify_requested_sneak() -> void:
	match fsm.current_state.name:
		"Run", "Idle":
			if fsm.knockback_vector == Vector2.ZERO:
				fsm.change_state("Sneak")
#endregion
