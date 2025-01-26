extends State
class_name ChaseState
## Handles when an entity is pursuing an enemy.

@export var chase_speed_mult: float = 1.0 ## A non-moddable modifier to the chase speed of the entity using this state.
@export var chase_sprint_speed_mult: float = 1.0 ## A non-moddable modifier to the sprint chase speed of the entity using this state.
@export_subgroup("Animation Constants")
@export var DEFAULT_RUN_ANIM_TIME_SCALE: float = 1.5 ## How fast the run anim should play before stat mods.
@export var MAX_RUN_ANIM_TIME_SCALE: float = 4.0 ## How fast the run anim can play at most.


func enter() -> void:
	entity.facing_component.travel_anim_tree("run")

func exit() -> void:
	pass

func state_physics_process(delta: float) -> void:
	_do_entity_chase(delta)
	_animate()

func _do_entity_chase(delta: float) -> void:
	var stats: StatModsCacheResource = entity.stats

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
				_do_entity_chase_with_sprint(stats, delta)
			else:
				_do_non_sprint_chase(stats, delta)
		else:
			_do_non_sprint_chase(stats, delta)

	entity.move_and_slide()

## Update the entity's velocity and animation speed during the sprint motion based on the current stats.
func _do_entity_chase_with_sprint(stats: StatModsCacheResource, delta: float) -> void:
	# Update anim speed multiplier
	var sprint_mult: float = stats.get_stat("sprint_multiplier")
	var max_speed: float = stats.get_stat("max_speed")
	var max_speed_change_factor: float = max_speed / stats.get_original_stat("max_speed")
	var anim_speed_mult: float = sprint_mult * (max_speed_change_factor)
	var final_anim_time_scale: float = min(MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE * anim_speed_mult)
	entity.facing_component.update_time_scale("run", final_anim_time_scale)

	# Update entity velocity
	var acceleration: float = stats.get_stat("acceleration")
	entity.velocity += (controller.get_movement_vector() * acceleration * sprint_mult * delta * chase_sprint_speed_mult)
	entity.velocity = entity.velocity.limit_length(max_speed * sprint_mult)

## Moves the entity with normal running movement based on the current stats.
func _do_non_sprint_chase(stats: StatModsCacheResource, delta: float) -> void:
	var anim_time_scale: float = min(MAX_RUN_ANIM_TIME_SCALE, DEFAULT_RUN_ANIM_TIME_SCALE * (stats.get_stat("max_speed") / stats.get_original_stat("max_speed")))
	entity.facing_component.update_time_scale("run", anim_time_scale)

	entity.velocity += (controller.get_movement_vector() * stats.get_stat("acceleration") * delta * chase_speed_mult)
	entity.velocity = entity.velocity.limit_length(stats.get_stat("max_speed"))

func _animate() -> void:
	entity.facing_component.update_blend_position("run")
