extends DynamicController
class_name DynamicAIController
## This subclass handles controlling dynamic AI entities such as enemies and player ally AI.

@export_group("Setup")
@export var path_delay_minmax: Vector2 = Vector2(0.5, 1.0) ## X is the min path recalc delay, Y is the max.
@export var local_avoidance_range: float = 15.0 ## How far away from the entity to scan for local collisions.
@export var ray_start_offset: Vector2 = Vector2.ZERO ## How much to offset the starting point of the raycasts.

@export_group("Movement Behavior")
@export_range(-1, 1, 0.01) var seek_weight: float = 1.0 ## How much we should move towards the target. Positives move towards, negatives move away.
@export_range(-1, 1, 0.01) var orbit_weight: float = 0.0 ## How much priority should be given to orbiting the target. Positive orbits clockwise (right). Negative orbits counterclockwise (left).
@export var preferred_distance: float = 30.0
@export_range(-1, 1, 0.01) var distance_weight: float = 1.0
@export var max_turn_rate: float = 1.5 ## How strongly the entity should turn.

const COLLISION_PENALTY: int = 6
var nav_agent: NavigationAgent2D ## The global nav agent.
var detector: DetectionComponent ## The detector component of the entity this is attached to, used to notify when enemies have entered or exited our detection range.
var target: Node2D ## The currently sought after target node.
var path_recalc_timer: Timer = TimerHelpers.create_repeating_timer(self, -1, _calculate_path_to_target) ## The timer tracking how long between recalculating the path to the target via the nav agent.
var raycast_results: Array[Dictionary] ## Stores the most recent set of raycast results.
var dir_interests: Array[float]
var ray_directions: Array[Vector2] = [ ## The directions in which rays are cast and avoidance is processed.
	Vector2.from_angle(0),
	Vector2.from_angle(PI / 4),
	Vector2.from_angle(PI / 2),
	Vector2.from_angle(3 * PI / 4),
	Vector2.from_angle(PI),
	Vector2.from_angle(5 * PI / 4),
	Vector2.from_angle(3 * PI / 2),
	Vector2.from_angle(7 * PI / 4)
	]


#region Debug
func _draw() -> void:
	if not DebugFlags.show_nav:
		return

	var max_score: float = -100000
	var min_score: float = 100000
	for score: float in dir_interests:
		if score < min_score:
			min_score = score
		if score > max_score:
			max_score = score

	var ray_start: Vector2 = entity.global_position + ray_start_offset
	for i: int in range(raycast_results.size()):
		var result: Dictionary = raycast_results[i]
		var direction: Vector2 = ray_directions[i]
		var ray_end: Vector2 = ray_start + (direction * local_avoidance_range)

		var score: float = 0.0
		if i < dir_interests.size() and max_score != min_score:
			score = (dir_interests[i] - min_score) / (max_score - min_score)
			score = clamp(score, 0.0, 1.0)
		else:
			score = 0.5
		var ray_color: Color = Color(1.0 - score, score, 0)

		if result.size() > 0:
			var hit_position: Vector2 = result["position"]
			draw_line(ray_start, hit_position, ray_color, 0.5)
			draw_circle(hit_position, 1.25, ray_color)
		else:
			draw_line(ray_start, ray_end, ray_color, 0.25)

	var movement_vector_end: Vector2 = entity.global_position + (last_movement_direction * 35)
	draw_line(entity.global_position, movement_vector_end, Color.YELLOW, 0.75)
#endregion

#region Core
## Sets up the controller with needed connections and references.
func setup() -> void:
	super()

	nav_agent = entity.get_node("NavigationAgent2D")
	detector = entity.detection_component
	detector.enemies_in_range_changed.connect(_on_enemies_in_range_changed)

	# Force check if we are in range of any enemies at spawn
	await get_tree().physics_frame
	_on_enemies_in_range_changed(detector.enemies_in_range)

## Called by the entity itself every frame.
func controller_process(delta: float) -> void:
	super(delta)
	entity.facing_component.update_facing_dir(facing_method)
#endregion

#region AI Navigation
## Returns the normalized direction in which the entity should move.
func get_movement_vector() -> Vector2:
	if DebugFlags.show_nav:
		raycast_results.clear()

	var agent_direction: Vector2 = get_nav_agent_next_direction()

	dir_interests.clear()
	for i: int in range(ray_directions.size()):
		dir_interests.append(ray_directions[i].dot(agent_direction))
		if _is_direction_blocked(entity.global_position + ray_start_offset, ray_directions[i]):
			dir_interests[i] -= COLLISION_PENALTY
			var size: int = dir_interests.size()
			var prev_index: int = (i - 1 + size) % size
			var next_index: int = (i + 1) % size
			dir_interests[prev_index] -= (COLLISION_PENALTY * 0.4)
			dir_interests[next_index] -= (COLLISION_PENALTY * 0.4)

	var preliminary_dir: Vector2 = _apply_movement_behaviors()

	last_movement_direction = steer_direction(preliminary_dir).rotated(entity.stats.get_stat("confusion_amount"))

	queue_redraw()
	return last_movement_direction

## Gets the next point in behthe nav agent's found path.
func get_nav_agent_next_direction() -> Vector2:
	var nav_point: Vector2 = nav_agent.get_next_path_position()
	return entity.to_local(nav_point).normalized()

## Checks a direction from the given start point to see if it is clear or not.
func _is_direction_blocked(ray_start: Vector2, direction: Vector2) -> bool:
	var ray_end: Vector2 = ray_start + (direction * local_avoidance_range)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [entity.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	if DebugFlags.show_nav:
		raycast_results.append(result)
	return not result.is_empty()

## Applies the extra movement behaviors as specified by the current move behavior resource.
func _apply_movement_behaviors() -> Vector2:
	if target == null:
		var best_index: int = ArrayHelpers.get_max_value_index(dir_interests)
		return ray_directions[best_index]

	var to_target: Vector2 = (target.global_position - entity.global_position).normalized()
	var dist_sq: float = entity.global_position.distance_squared_to(target.global_position)
	var preferred_dist_sq: float = preferred_distance * preferred_distance
	var dead_zone_sq: float = 16.0 # pixels squared dead zone

	for i: int in range(dir_interests.size()):
		var direction: Vector2 = ray_directions[i]
		var dot_to_target: float = direction.dot(to_target)
		var score: float = dir_interests[i]

		# Seek/flee
		score += dot_to_target * seek_weight

		# Maintain distance
		if distance_weight > 0.01:
			if dist_sq < preferred_dist_sq - dead_zone_sq:
				score -= dot_to_target * distance_weight
			elif dist_sq > preferred_dist_sq + dead_zone_sq:
				score += dot_to_target * distance_weight

		# Orbit
		if abs(orbit_weight) >= 0.01:
			var orbit_dir: Vector2 = Vector2(-to_target.y, to_target.x)
			score += direction.dot(orbit_dir) * orbit_weight

		dir_interests[i] = score

	var new_best_dir_index: int = ArrayHelpers.get_max_value_index(dir_interests)
	return ray_directions[new_best_dir_index]

## Steers the last movement direction towards the desired direction.
func steer_direction(desired_dir: Vector2) -> Vector2:
	if last_movement_direction == Vector2.ZERO:
		return desired_dir

	var angle_diff: float = last_movement_direction.angle_to(desired_dir)
	var delta: float = get_physics_process_delta_time()
	var angle_change: float = clampf(angle_diff, -max_turn_rate * delta, max_turn_rate * delta)
	return last_movement_direction.rotated(angle_change)
#endregion

## Determines if the state controlling the movement should use sprinting.
func get_should_sprint() -> bool:
	return false

## Called automatically when the detector component emits that the list of enemies in range has changed.
func _on_enemies_in_range_changed(enemies_in_range: Array[Entity] = detector.enemies_in_range) -> void:
	if enemies_in_range.is_empty():
		target = null
		path_recalc_timer.stop()
		match fsm.current_state.state_id:
			"chase", "knockback":
				fsm.change_state("idle")
	else:
		if target not in enemies_in_range:
			target = null
			_determine_target()
		notify_enemy_in_range()

## Picks a random target from the targets in range and notifies the navigation agent.
func _determine_target() -> void:
	var num_targets: int = detector.enemies_in_range.size()
	if num_targets > 0:
		target = detector.enemies_in_range[randi_range(0, num_targets - 1)]
		_calculate_path_to_target()

## If we have a valid target, this recalculates the path by reassigning the target's position to the next
## path position in the nav agent.
func _calculate_path_to_target() -> void:
	if target:
		nav_agent.target_position = target.global_position
		path_recalc_timer.wait_time = randf_range(path_delay_minmax.x, path_delay_minmax.y)
		path_recalc_timer.start()

#region Notification Overrides
## Requests to add a value to the current knockback vector, doing so if possible.
func notify_requested_knockback(knockback: Vector2) -> void:
	match fsm.current_state.state_id:
		"sneak", "idle", "stunned", "chase":
			knockback_vector = (knockback_vector + knockback).limit_length(MAX_KNOCKBACK)
			fsm.change_state("knockback")
			reset_and_create_knockback_streak()

## When a knockback vector is no longer moving the entity, this is called.
func notify_knockback_ended() -> void:
	fsm.change_state("idle")
	_on_enemies_in_range_changed()

## Called when the spawn animation ends.
func notify_spawn_ended() -> void:
	fsm.change_state("idle")
	_on_enemies_in_range_changed()

## Called to request starting being stunned.
func notify_requested_stun(duration: float) -> void:
	match fsm.current_state.state_id:
		"chase", "idle", "stunned":
			stunned_timer.wait_time = duration
			fsm.change_state("stunned")
			stunned_timer.start()

## When the stun timer ends, notify that we can return to Idle if needed, but check if we
## have enemies in range first.
func notify_stun_ended() -> void:
	fsm.change_state("idle")
	_on_enemies_in_range_changed()

## Called when an enemy enters the detection zone.
func notify_enemy_in_range() -> void:
	match fsm.current_state.state_id:
		"idle":
			_determine_target()
			if fsm.has_state("chase"):
				fsm.change_state("chase")
#endregion
