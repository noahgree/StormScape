extends State
class_name RunState
## Handles when the dynamic entity is moving, including both running and sprinting.

@export_subgroup("Animation Constants")
@export var DEFAULT_RUN_ANIM_TIME_SCALE: float = 1.5 ## How fast the run anim should play before stat mods.
@export var MAX_RUN_ANIM_TIME_SCALE: float = 4.0 ## How fast the run anim can play at most.

var is_sprint_audio_playing: bool = false ## Whether the character's sprint is producing sprint audio.
var previous_pos: Vector2 ## The previous position of the entity as of the last frame. Used for speed calculations to determine if sprint audio should play for the player.
var actual_movement_speed: float = 0 ## The movement speed determined by change in distance over time.


func enter() -> void:
	previous_pos = entity.global_position
	entity.facing_component.travel_anim_tree("run")

func exit() -> void:
	_stop_sprint_sound()
	is_sprint_audio_playing = false

func state_physics_process(delta: float) -> void:
	_do_entity_run(delta)
	_animate()

## Besides appropriately applying velocity to the parent entity, this checks and potentially activates sprinting
## as well as calculates what vector the animation state machine should receive to play
## the matching directional anim.
func _do_entity_run(delta: float) -> void:
	var stats: StatModsCacheResource = entity.stats
	actual_movement_speed = (entity.global_position - previous_pos).length() / delta
	previous_pos = entity.global_position

	# Check if we should stop the sprint sound based on movement speed.
	if ceil(actual_movement_speed) <= floor(stats.get_stat("max_speed")):
		if is_sprint_audio_playing:
			_stop_sprint_sound()
			is_sprint_audio_playing = false
			AudioManager.change_sfx_resource_rhythmic_delay("PlayerRunBase", 0.03)

	if controller.knockback_vector.length() > 0:
		entity.velocity = controller.knockback_vector

	if controller.get_movement_vector() == Vector2.ZERO: # We have no input and should slow to a stop
		if entity.velocity.length() > (stats.get_stat("friction") * delta): # No input, still slowing
			var slow_rate_vector: Vector2 = entity.velocity.normalized() * (stats.get_stat("friction") * delta)
			entity.velocity -= slow_rate_vector
		else: # No input, stopped
			controller.knockback_vector = Vector2.ZERO
			entity.velocity = Vector2.ZERO
			controller.notify_stopped_moving()
	elif controller.knockback_vector.length() == 0: # We have input and there is no knockback
		if controller.get_should_sprint():
			if entity.stamina_component.use_stamina(entity.stats.get_stat("sprint_stamina_usage") * delta):
				_do_entity_sprint(stats, delta)
			else:
				_do_non_sprint_movement(stats, delta)
		else:
			_do_non_sprint_movement(stats, delta)

	entity.move_and_slide()
	_handle_rigid_entity_collisions()

## Update the entity's velocity and animation speed during the sprint motion based on the current stats.
func _do_entity_sprint(stats: StatModsCacheResource, delta: float) -> void:
	# Remove the run sound's rhythmic delay during sprint since it needs to play faster
	AudioManager.change_sfx_resource_rhythmic_delay("PlayerRunBase", 0)

	# Update anim speed multiplier
	var sprint_mult: float = stats.get_stat("sprint_multiplier")
	var max_speed: float = stats.get_stat("max_speed")
	var max_speed_change_factor: float = max_speed / stats.get_original_stat("max_speed")
	var anim_speed_mult: float = sprint_mult * (max_speed_change_factor)
	var final_anim_time_scale: float = min(MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE * anim_speed_mult)
	entity.facing_component.update_time_scale("run", final_anim_time_scale)

	# Update entity velocity
	var acceleration: float = stats.get_stat("acceleration")
	entity.velocity += (controller.get_movement_vector() * acceleration * sprint_mult * delta)
	entity.velocity = entity.velocity.limit_length(max_speed * sprint_mult)

	# Do sprinting sounds if we are moving fast enoughd
	if actual_movement_speed > entity.stats.get_stat("max_speed"):
		_play_sprint_sound()
		is_sprint_audio_playing = true

## Moves the entity with normal running movement based on the current stats.
func _do_non_sprint_movement(stats: StatModsCacheResource, delta: float) -> void:
	var anim_time_scale: float = min(MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE * (stats.get_stat("max_speed") / stats.get_original_stat("max_speed")))
	entity.facing_component.update_time_scale("run", anim_time_scale)

	entity.velocity += (controller.get_movement_vector() * stats.get_stat("acceleration") * delta)
	entity.velocity = entity.velocity.limit_length(stats.get_stat("max_speed"))

## Handles moving rigid entities that we collided with in the last frame.
func _handle_rigid_entity_collisions() -> void:
	for i: int in entity.get_slide_collision_count():
		var c: KinematicCollision2D = entity.get_slide_collision(i)
		var collider: Object = c.get_collider()
		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal().normalized() * entity.velocity.length() / (10 / (entity.stats.get_stat("run_collision_impulse_factor"))))

func _animate() -> void:
	entity.facing_component.update_blend_position("run")

func _play_run_sound() -> void:
	AudioManager.play_2d("player_run_base", entity.global_position)

func _play_sprint_sound() -> void:
	if not is_sprint_audio_playing:
		AudioManager.play_global("player_sprint_wind", 0.5)

func _stop_sprint_sound() -> void:
	if is_sprint_audio_playing:
		AudioManager.stop_sound_id("player_sprint_wind", 0.3, 1, true)
