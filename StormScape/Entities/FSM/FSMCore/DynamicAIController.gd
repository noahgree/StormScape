extends DynamicController
class_name DynamicAIController
## This subclass handles controlling dynamic AI entities such as enemies and player ally AI.

@export var path_delay_minmax: Vector2 = Vector2(0.75, 1.25) ## X is the min path recalc delay, Y is the max.
@export var local_avoidance_range: float = 15.0 ## How far to scan for local obstacles.
@export var ray_start_offset: Vector2 ## Where relative to the global pos of the entity should the local rays start from.
@export var global_weight: float = 0.2 ## The importance of the global nav agent path in the final direction.
@export var local_weight: float = 0.8 ## The importance of the local obstacle detection in the final direction.
@export var smoothing_factor: float = 0.28
@export var momentum_penalty: float = 0.12
@export var candidate_clearance_threshold: float = 12.0
@export var min_gap_adjacent_score: float = 0.5

var nav_agent: NavigationAgent2D ## The global nav agent.
var local_avoidance_update_freq: int = randi_range(8, 12)
var detector: DetectionComponent
var should_sprint: bool = false
var target: Entity = null
var path_recalc_timer: Timer = TimerHelpers.create_repeating_timer(self, -1, _calculate_path_to_target)
var raycast_results: Array[Dictionary] = []
var last_movement_direction: Vector2
var fallback_dir: Vector2
var fallback_dir_recalc_counter: float = 1.5
var last_candidate_scores: Array = []
var ray_directions: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(1, 1).normalized(),
	Vector2(0, 1),
	Vector2(-1, 1).normalized(),
	Vector2(-1, 0),
	Vector2(-1, -1).normalized(),
	Vector2(0, -1),
	Vector2(1, -1).normalized()
]


#region Debug
func _draw() -> void:
	if not DebugFlags.show_collision_avoidance_rays:
		return

	var ray_start: Vector2 = entity.global_position + ray_start_offset

	for i: int in range(raycast_results.size()):
		var result: Dictionary = raycast_results[i]
		var direction: Vector2 = ray_directions[i]
		var ray_end: Vector2 = ray_start + (direction * local_avoidance_range)

		# Use candidate score to decide the ray color
		var score: float = 0.0
		if i < last_candidate_scores.size():
			score = clamp(last_candidate_scores[i], 0, 1)
		var ray_color: Color = Color(1.0 - score, score, 0)

		if result.size() > 0:
			var hit_position: Vector2 = result["position"]
			draw_line(ray_start, hit_position, ray_color, 0.5)
			draw_circle(hit_position, 1.25, ray_color)
		else:
			draw_line(ray_start, ray_end, ray_color, 0.25)

	if not DebugFlags.show_movement_vector:
		return
	var movement_vector_end: Vector2 = entity.global_position + (last_movement_direction * 35)
	draw_line(entity.global_position, movement_vector_end, Color.YELLOW, 0.75)
#endregion

func setup() -> void:
	super.setup()

	nav_agent = entity.get_node("NavigationAgent2D")
	detector = entity.detection_component
	detector.enemies_in_range_changed.connect(_on_enemies_in_range_changed)
	await get_tree().physics_frame

	# Force check if we are in range of any enemies at spawn
	_on_enemies_in_range_changed(detector.enemies_in_range)

func controller_process(delta: float) -> void:
	super.controller_process(delta)

	entity.facing_component.update_facing_dir(FacingComponent.Method.MOVEMENT_DIR)
	fallback_dir_recalc_counter = max(0, fallback_dir_recalc_counter - delta)
	if fallback_dir_recalc_counter <= 0:
		fallback_dir_recalc_counter = 1.5
		fallback_dir = VectorHelpers.random_direction()

#region Inputs
func get_movement_vector() -> Vector2:
	if Engine.get_physics_frames() % local_avoidance_update_freq == 0:
		queue_redraw()
		return last_movement_direction

	# --- Global Navigation Direction ---
	var nav_point: Vector2 = nav_agent.get_next_path_position()
	var nav_direction: Vector2 = entity.to_local(nav_point).normalized()

	# --- Local Candidate Evaluation (one ray per candidate) ---
	var best_direction: Vector2 = nav_direction
	var best_score: float = -1.0
	var best_index: int = -1
	var candidate_scores: Array = []
	raycast_results.clear()
	var ray_start: Vector2 = entity.global_position + ray_start_offset

	for i: int in range(ray_directions.size()):
		var direction: Vector2 = ray_directions[i]
		# Base score based on alignment with the global nav direction
		var score: float = (nav_direction.dot(direction) + 1.0) / 2.0

		# Cast the ray once
		var result: Dictionary = _is_direction_blocked(ray_start, direction)
		raycast_results.append(result)

		# If an obstacle is hit, reduce the score based on its proximity
		if not result.is_empty():
			var distance: float = ray_start.distance_to(result["position"])
			var penalty: float = (local_avoidance_range - distance) / local_avoidance_range
			score *= clamp(1.0 - penalty, 0.0, 1.0)

		# --- Momentum Preservation ---
		var momentum_dot: float = last_movement_direction.dot(direction)
		if momentum_dot < 0.0:
			score *= momentum_penalty

		candidate_scores.append(score)

		if score > best_score:
			best_score = score
			best_direction = direction
			best_index = i

	# Store candidate scores for debugging
	last_candidate_scores = candidate_scores.duplicate()

	# --- Candidate Clearance Check ---
	var candidate_clear: bool = false
	if best_index != -1:
		var best_result: Dictionary = raycast_results[best_index]
		if best_result.is_empty():
			candidate_clear = true
		else:
			var hit_distance: float = ray_start.distance_to(best_result["position"])
			if hit_distance >= candidate_clearance_threshold:
				candidate_clear = true
			else:
				candidate_clear = false

		# Also check the adjacent candidate scores
		var left_index: int = best_index - 1
		var right_index: int = best_index + 1
		if left_index < 0:
			left_index = ray_directions.size() - 1
		if right_index >= ray_directions.size():
			right_index = 0
		# Only if both adjacent scores are too low do we mark the gap as too narrow
		if (candidate_scores[left_index] < min_gap_adjacent_score or candidate_scores[right_index] < min_gap_adjacent_score):
			candidate_clear = false
	else:
		candidate_clear = false

	# --- Fallback if no good candidate exists ---
	if best_score < 0.1:
		best_direction = (best_direction + fallback_dir).normalized()

	# --- Adding Confusion ---
	best_direction = best_direction.rotated(entity.stats.get_stat("confusion_amount"))

	# --- Preliminary Blending ---
	var preliminary_direction: Vector2 = ((nav_direction * global_weight) + (best_direction * local_weight)).normalized()

	# --- Extra Avoidance (Only if the best candidate isn't considered clear) ---
	if not candidate_clear:
		var avoidance_force: Vector2 = Vector2.ZERO
		# Only consider rays that are roughly in the direction of the best candidate (within 45°)
		for i: int in range(ray_directions.size()):
			var candidate: Vector2 = ray_directions[i]
			if abs(best_direction.angle_to(candidate)) < deg_to_rad(45):
				var result: Dictionary = raycast_results[i]
				if not result.is_empty():
					var distance: float = ray_start.distance_to(result["position"])
					# Only add force if the obstacle is very near (within 50% of local_avoidance_range)
					if distance < local_avoidance_range * 0.5 and result.has("normal"):
						var strength: float = (local_avoidance_range - distance) / local_avoidance_range
						avoidance_force += result["normal"] * strength
		if avoidance_force != Vector2.ZERO:
			preliminary_direction = (preliminary_direction + (avoidance_force)).normalized()

	# --- Dynamic Smoothing ---
	var angle_diff: float = last_movement_direction.angle_to(preliminary_direction)
	var dynamic_smoothing: float = smoothing_factor
	if angle_diff > deg_to_rad(45):
		dynamic_smoothing = smoothing_factor * 0.5

	var smoothed_direction: Vector2 = last_movement_direction.lerp(preliminary_direction, dynamic_smoothing)
	last_movement_direction = smoothed_direction

	queue_redraw()
	return smoothed_direction

func get_should_sprint() -> bool:
	return should_sprint
#endregion

func _is_direction_blocked(ray_start: Vector2, direction: Vector2) -> Dictionary:
	var ray_end: Vector2 = ray_start + (direction * local_avoidance_range)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [entity.get_rid()]
	return space_state.intersect_ray(query)

func _on_enemies_in_range_changed(enemies_in_range: Array[Entity]) -> void:
	if enemies_in_range.is_empty():
		target = null
		path_recalc_timer.stop()
		match fsm.current_state.state_id:
			"chase":
				fsm.change_state("idle")
	else:
		if target not in enemies_in_range:
			target = null
			_determine_target()
		notify_enemy_in_range()

## When the stun timer ends, notify that we can return to Idle if needed, but check if we
## have enemies in range first.
func _on_stun_timer_timeout() -> void:
	fsm.change_state("idle")

	if not detector.enemies_in_range.is_empty():
		notify_enemy_in_range()

## Requests to add a value to the current knockback vector, doing so if possible.
func notify_requested_knockback(knockback: Vector2) -> void:
	match fsm.current_state.state_id:
		"sneak", "idle", "stunned", "chase":
			knockback_vector = (knockback_vector + knockback).limit_length(MAX_KNOCKBACK)
			reset_and_create_knockback_streak()

func notify_spawn_ended() -> void:
	fsm.change_state("idle")

	if detector.enemies_in_range.is_empty():
		notify_stopped_moving()
	else:
		notify_enemy_in_range()

func notify_requested_stun(duration: float) -> void:
	match fsm.current_state.state_id:
		"chase", "idle", "stunned":
			stunned_timer.wait_time = duration
			fsm.change_state("stunned")
			stunned_timer.start()

func notify_enemy_in_range() -> void:
	match fsm.current_state.state_id:
		"idle":
			_determine_target()
			if fsm.has_state("chase"):
				fsm.change_state("chase")

func _determine_target() -> void:
	var num_targets: int = detector.enemies_in_range.size()
	if num_targets > 0:
		target = detector.enemies_in_range[randi_range(0, num_targets - 1)]
		_calculate_path_to_target()

func _calculate_path_to_target() -> void:
	if target:
		nav_agent.target_position = target.global_position
		path_recalc_timer.wait_time = randf_range(path_delay_minmax.x, path_delay_minmax.y)
		path_recalc_timer.start()
