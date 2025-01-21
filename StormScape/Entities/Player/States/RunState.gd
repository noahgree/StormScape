extends State
class_name RunState
## Handles when the dynamic entity is moving, including both running and sprinting.

@export var _max_speed: float = 150 ## The maximum speed the entity can travel once fully accelerated.
@export var _acceleration: float = 1250 ## The increase in speed per second for the entity.
@export var _sprint_multiplier: float = 1.5 ## How much faster the max_speed should be when sprinting.
@export var _run_collision_impulse_factor: float = 1.0 ## A multiplier that controls how much impulse gets applied to rigid entites when colliding with them during the run state.

const DEFAULT_RUN_ANIM_TIME_SCALE: float = 1.5 ## How fast the run anim should play before stat mods.
const MAX_RUN_ANIM_TIME_SCALE: float = 4.0 ## How fast the run anim can play at most.
var movement_vector: Vector2 = Vector2.ZERO ## The current movement vector for the entity.
var is_sprint_audio_playing: bool = false ## Whether the character's sprint is producing sprint audio.
var previous_pos: Vector2 ## The previous position of the entity as of the last frame.
var actual_movement_speed: float = 0 ## The movement speed determined by change in distance over time.


func _ready() -> void:
	var moddable_stats: Dictionary[StringName, float] = {
		&"max_speed" : _max_speed, &"acceleration" : _acceleration,
		&"sprint_multiplier" : _sprint_multiplier, &"run_collision_impulse_factor" : _run_collision_impulse_factor
	}
	get_parent().entity.stats.add_moddable_stats(moddable_stats)

func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("run")
	previous_pos = entity.global_position

func exit() -> void:
	_stop_sprint_sound()
	is_sprint_audio_playing = false

func state_physics_process(delta: float) -> void:
	_do_character_run(delta)
	_check_for_dash_request()
	_check_for_sneak_request()
	_animate()

## Besides appropriately applying velocity to the parent entity, this checks and potentially activates sprinting
## as well as calculates what vector the animation state machine should receive to play the matching directional anim.
func _do_character_run(delta: float) -> void:
	var stats: StatModsCacheResource = entity.stats
	movement_vector = _calculate_move_vector(stats)
	actual_movement_speed = (entity.global_position - previous_pos).length() / delta
	previous_pos = entity.global_position

	# Check if we should stop the sprint sound based on movement speed.
	if ceil(actual_movement_speed) <= floor(stats.get_stat("max_speed")):
		if is_sprint_audio_playing:
			_stop_sprint_sound()
			is_sprint_audio_playing = false
			AudioManager.change_sfx_resource_rhythmic_delay("PlayerRunBase", 0.03)

	var curr_velocity: Vector2 = entity.velocity

	if fsm.knockback_vector.length() > 0:
		entity.velocity = fsm.knockback_vector

	if movement_vector == Vector2.ZERO: # We have no input and should slow to a stop
		if curr_velocity.length() > (stats.get_stat("friction") * delta): # No input, still slowing
			var slow_rate_vector: Vector2 = curr_velocity.normalized() * (stats.get_stat("friction") * delta)
			entity.velocity -= slow_rate_vector
		else: # No input, stopped
			fsm.knockback_vector = Vector2.ZERO
			entity.velocity = Vector2.ZERO
			transitioned.emit(self, "Idle")
	elif fsm.knockback_vector.length() == 0: # We have input and there is no knockback
		if Input.is_action_pressed("sprint"):
			if entity.stamina_component.use_stamina(entity.stats.get_stat("sprint_stamina_usage") * delta):
				_do_sprinting(stats, delta)
			else:
				_do_non_sprint_movement(stats, delta)
		else:
			_do_non_sprint_movement(stats, delta)

	entity.move_and_slide()
	_handle_rigid_entity_collisions()

## Update the entity's velocity and animation speed during the sprint motion based on the current stats.
func _do_sprinting(stats: StatModsCacheResource, delta: float) -> void:
	# Remove the run sound's rhythmic delay during sprint since it needs to play faster.
	AudioManager.change_sfx_resource_rhythmic_delay("PlayerRunBase", 0)

	# Update anim speed multiplier.
	var sprint_mult: float = stats.get_stat("sprint_multiplier")
	var max_speed: float = stats.get_stat("max_speed")
	var max_speed_change_factor: float = max_speed / stats.get_original_stat("max_speed")
	var anim_speed_mult: float = sprint_mult * (max_speed_change_factor)
	fsm.anim_tree.set("parameters/run/TimeScale/scale", min(MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE * anim_speed_mult))

	# Update entity velocity.
	var acceleration: float = stats.get_stat("acceleration")
	entity.velocity += (movement_vector * acceleration * sprint_mult * delta)
	entity.velocity = entity.velocity.limit_length(max_speed * sprint_mult)

	# Do sprinting sounds if we are moving fast enough.
	if actual_movement_speed > entity.stats.get_stat("max_speed"):
		_play_sprint_sound()
		is_sprint_audio_playing = true

## Moves the entity with normal running movement based on the current stats.
func _do_non_sprint_movement(stats: StatModsCacheResource, delta: float) -> void:
	fsm.anim_tree.set("parameters/run/TimeScale/scale", min(MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE * (stats.get_stat("max_speed") / stats.get_original_stat("max_speed"))))

	entity.velocity += (movement_vector * stats.get_stat("acceleration") * delta)
	entity.velocity = entity.velocity.limit_length(stats.get_stat("max_speed"))

## Handles moving rigid entities that we collided with in the last frame.
func _handle_rigid_entity_collisions() -> void:
	for i: int in entity.get_slide_collision_count():
		var c: KinematicCollision2D = entity.get_slide_collision(i)
		var collider: Object = c.get_collider()
		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal().normalized() * entity.velocity.length() / (10 / (entity.stats.get_stat("run_collision_impulse_factor"))))

## Gets the movement vector depending on external factors like confusion.
func _calculate_move_vector(stats: StatModsCacheResource) -> Vector2:
	if _get_input_vector() == Vector2.ZERO:
		return _get_input_vector()
	else:
		return (_get_input_vector().rotated(stats.get_stat("confusion_amount")))

## If the dash button is pressed and we are not on dash cooldown, we check if we have enough stamina to dash.
## If the use_stamina request is successful, we enter the dash state having already decremented the stamina amount.
func _check_for_dash_request() -> void:
	if _is_dash_requested() and fsm.dash_cooldown_timer.is_stopped() and movement_vector != Vector2.ZERO:
		if entity.stamina_component.use_stamina(entity.stats.get_stat("dash_stamina_usage")):
			transitioned.emit(self, "Dash")

## Checks if we meet the input (or otherwise) conditions to start sneaking. If so, transition to sneak.
func _check_for_sneak_request() -> void:
	if _is_sneak_requested() and fsm.knockback_vector == Vector2.ZERO:
		transitioned.emit(self, "Sneak")

func _animate() -> void:
	fsm.anim_tree.set("parameters/run/blendspace2d/blend_position", fsm.anim_vector)

func _play_run_sound() -> void:
	AudioManager.play_sound("PlayerRunBase", AudioManager.SoundType.SFX_2D, entity.global_position)

func _play_sprint_sound() -> void:
	if not is_sprint_audio_playing:
		AudioManager.fade_in_sound("PlayerSprintWind", AudioManager.SoundType.SFX_GLOBAL, 0.5)

func _stop_sprint_sound() -> void:
	if is_sprint_audio_playing:
		AudioManager.fade_out_sound_by_name("PlayerSprintWind", 0.3, 1, true)
