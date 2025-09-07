class_name NavManager
## Manages the heavy lifting for the navigation and target selection for the AI Controller.

const COLLISION_PENALTY: int = 6 ## How much to penalize a direction in which there is something in the way.
var controller: DynamicAIController ## The owning controller that created this script.
var nav_agent: NavigationAgent2D ## The global nav agent.
var path_recalc_timer: Timer ## The timer tracking how long between recalculating the path to the target via the nav agent.
var raycast_results: Array[Dictionary] ## Stores the most recent set of raycast results.
var dir_interests: Array[float] ## Stores the most recent interest array for weighting which direction to move.
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


## Initializes the needed reference to the controller when created.
func _init(controller_node: DynamicAIController) -> void:
	controller = controller_node
	path_recalc_timer = TimerHelpers.create_repeating_timer(controller, -1, _calculate_path_to_target)

#region Target Selection
## If we have a valid target, this recalculates the path by reassigning the target's position to the next
## path position in the nav agent.
func _calculate_path_to_target() -> void:
	if controller.target:
		nav_agent.target_position = controller.target.global_position
		path_recalc_timer.wait_time = randf_range(controller.path_delay_minmax.x, controller.path_delay_minmax.y)
		path_recalc_timer.start()

## Picks a random target from the targets in range and notifies the navigation agent.
func determine_target() -> void:
	var num_targets: int = controller.detector.enemies_in_range.size()
	if num_targets > 0:
		controller.target = controller.detector.enemies_in_range[randi_range(0, num_targets - 1)]
		_calculate_path_to_target()
#endregion

#region Movement Vector
## Returns the normalized direction in which the entity should move.
func get_movement_vector() -> Vector2:
	if DebugFlags.show_nav:
		raycast_results.clear()

	var agent_direction: Vector2 = _get_nav_agent_next_direction()

	dir_interests.clear()
	for i: int in range(ray_directions.size()):
		dir_interests.append(ray_directions[i].dot(agent_direction))
		if _is_direction_blocked(controller.entity.global_position + controller.ray_start_offset, ray_directions[i]):
			dir_interests[i] -= COLLISION_PENALTY
			var size: int = dir_interests.size()
			var prev_index: int = (i - 1 + size) % size
			var next_index: int = (i + 1) % size
			dir_interests[prev_index] -= (COLLISION_PENALTY * 0.4)
			dir_interests[next_index] -= (COLLISION_PENALTY * 0.4)

	var preliminary_dir: Vector2 = _apply_movement_behaviors()

	controller.last_movement_direction = _steer_direction(preliminary_dir).rotated(controller.entity.stats.get_stat("confusion_amount"))

	return controller.last_movement_direction

## Gets the next point in behthe nav agent's found path.
func _get_nav_agent_next_direction() -> Vector2:
	var nav_point: Vector2 = nav_agent.get_next_path_position()
	return controller.entity.to_local(nav_point).normalized()

## Checks a direction from the given start point to see if it is clear or not.
func _is_direction_blocked(ray_start: Vector2, direction: Vector2) -> bool:
	var ray_end: Vector2 = ray_start + (direction * controller.local_avoidance_range)
	var space_state: PhysicsDirectSpaceState2D = controller.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [controller.entity.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)

	if DebugFlags.show_nav:
		raycast_results.append(result)
	return not result.is_empty()

## Applies the extra movement behaviors as specified by the current move behavior resource.
func _apply_movement_behaviors() -> Vector2:
	if controller.target == null:
		var best_index: int = ArrayHelpers.get_max_value_index(dir_interests)
		return ray_directions[best_index]

	var to_target: Vector2 = (controller.target.global_position - controller.entity.global_position).normalized()
	var dist_sq: float = controller.entity.global_position.distance_squared_to(controller.target.global_position)
	var preferred_dist_sq: float = controller.behavior.preferred_distance * controller.behavior.preferred_distance
	var dead_zone_sq: float = 15.0 # The real dead zone is the square root of this

	for i: int in range(dir_interests.size()):
		var direction: Vector2 = ray_directions[i]
		var dot_to_target: float = direction.dot(to_target)
		var score: float = dir_interests[i]

		# Seek/Flee
		score += dot_to_target * controller.behavior.seek_weight

		# Maintain distance
		if controller.behavior.distance_weight > 0.01:
			if dist_sq < preferred_dist_sq - dead_zone_sq:
				score -= dot_to_target * controller.behavior.distance_weight
			elif dist_sq > preferred_dist_sq + dead_zone_sq:
				score += dot_to_target * controller.behavior.distance_weight

		# Orbit
		if abs(controller.behavior.orbit_weight) >= 0.01:
			var orbit_dir: Vector2 = Vector2(-to_target.y, to_target.x)
			score += direction.dot(orbit_dir) * controller.behavior.orbit_weight

		dir_interests[i] = score

	var new_best_dir_index: int = ArrayHelpers.get_max_value_index(dir_interests)
	return ray_directions[new_best_dir_index]

## Steers the last movement direction towards the desired direction.
func _steer_direction(desired_dir: Vector2) -> Vector2:
	if controller.last_movement_direction == Vector2.ZERO:
		return desired_dir

	var angle_diff: float = controller.last_movement_direction.angle_to(desired_dir)
	var delta: float = controller.get_physics_process_delta_time()
	var angle_change: float = clampf(angle_diff, -controller.behavior.max_turn_rate * delta, controller.behavior.max_turn_rate * delta)
	return controller.last_movement_direction.rotated(angle_change)
#endregion
