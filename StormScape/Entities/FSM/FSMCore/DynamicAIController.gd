extends DynamicController
class_name DynamicAIController
## This subclass handles controlling dynamic AI entities such as enemies and player ally AI.

@export_group("Avoidance Setup")
@export var path_delay_minmax: Vector2 = Vector2(0.5, 1.0) ## X is the min path recalc delay, Y is the max.
@export_range(0, 1, 0.01) var global_weight: float = 0.2 ## How strongly we should prioriize moving directly along the A* path from the nav agent to the target.
@export_range(0, 1, 0.01) var local_weight: float = 0.8 ## How strongly we should prioritize moving exactly as our local avoidance vector tells us instead of paying attention to the global nav_direction's wishes.
@export var local_avoidance_range: float = 16.0 ## How far away from the entity to scan for local collisions.
@export var ray_start_offset: Vector2 = Vector2.ZERO ## How much to offset the starting point of the raycasts.

@export_group("Avoidance Details")
@export_range(0.01, 1, 0.01) var smoothing_factor: float = 0.15 ## The lerping rate for changing direction.
@export_range(0.01, 1, 0.01) var momentum_penalty_mult: float = 0.1 ## Penalizes directions that are 120º or more different from the current direction.
@export var candidate_clearance_threshold: float = 12.0 ## How far away ray collisions must be when checking to see if we can fit through a gap (happens when the main direction is open but the ones adjacent to it are not).
@export var avoidance_multiplier: float = 2.0 ## How much to multiply the motion that occurs when avoiding a local obstacle by.

@export_group("Movement Behavior")
@export var behavior: MoveBehaviorResource = MoveBehaviorResource.new()

var nav_agent: NavigationAgent2D ## The global nav agent.
var detector: DetectionComponent ## The detector component of the entity this is attached to, used to notify when enemies have entered or exited our detection range.
var target: Node2D = null ## The currently sought after target node.
var path_recalc_timer: Timer = TimerHelpers.create_repeating_timer(self, -1, _calculate_path_to_target) ## The timer tracking how long between recalculating the path to the target via the nav agent.
var raycast_results: Array[Dictionary] = [] ## Stores the most recent set of raycast results.
var last_candidate_scores: Array = [] ## The most recent set of scores for each possible direction.
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

	var movement_vector_end: Vector2 = entity.global_position + (last_movement_direction * 35)
	draw_line(entity.global_position, movement_vector_end, Color.YELLOW, 0.75)
#endregion

func setup() -> void:
	super.setup()

	nav_agent = entity.get_node("NavigationAgent2D")
	detector = entity.detection_component
	detector.enemies_in_range_changed.connect(_on_enemies_in_range_changed)

	# Force check if we are in range of any enemies at spawn
	await get_tree().physics_frame
	_on_enemies_in_range_changed(detector.enemies_in_range)

func controller_process(delta: float) -> void:
	super(delta)
	entity.facing_component.update_facing_dir(facing_method)

#region Movement Vector
#===========================================================================
# Main entry point: Compute and return the entity’s movement vector.
#===========================================================================
func get_movement_vector() -> Vector2:
	var nav_direction: Vector2 = get_global_nav_direction()

	# If we don't consider the local avoidance at all, just return nav_agent's direction
	if local_weight == 0:
		queue_redraw()
		return nav_direction

	# Evaluate the local candidates
	var ray_start: Vector2 = entity.global_position + ray_start_offset
	var candidate_data: Dictionary = evaluate_local_candidates(ray_start, nav_direction)
	var best_local_direction: Vector2 = candidate_data["best_direction"]
	var best_index: int = candidate_data["best_index"]
	var candidate_scores: Array[float] = candidate_data["candidate_scores"]

	# If candidate clearance fails, compute the avoidance force
	var candidate_clear: bool = is_candidate_clear(best_index, candidate_scores, ray_start)
	if not candidate_clear:
		var avoidance: Vector2 = compute_avoidance_force(ray_start, best_index)
		avoidance *= avoidance_multiplier

		best_local_direction = (best_local_direction + avoidance).normalized()

		# If the avoidance force is very strong and is driving backward, override entire local movement vector
		if avoidance.length() > 0 and avoidance.dot(best_local_direction) < 0:
			best_local_direction = avoidance.normalized()

	# Blend in target-based behavior
	best_local_direction = apply_target_behavior(best_local_direction)

	# Apply any confusion effects
	best_local_direction = best_local_direction.rotated(entity.stats.get_stat("confusion_amount"))

	# Smooth the new direction with the last frame’s movement
	last_movement_direction = apply_dynamic_smoothing(best_local_direction, last_movement_direction).normalized()

	queue_redraw()
	return last_movement_direction

#===========================================================================
# Helper: Cast a ray in the given direction for local obstacle checking.
#===========================================================================
func _is_direction_blocked(ray_start: Vector2, direction: Vector2) -> Dictionary:
	var ray_end: Vector2 = ray_start + (direction * local_avoidance_range)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [entity.get_rid()]
	return space_state.intersect_ray(query)

#===========================================================================
# Step 1: Get the global navigation direction from the NavigationAgent.
#===========================================================================
func get_global_nav_direction() -> Vector2:
	var nav_point: Vector2 = nav_agent.get_next_path_position()
	return entity.to_local(nav_point).normalized()

#===========================================================================
# Step 2: Evaluate local candidate directions via raycasts, scoring each.
# Returns a Dictionary with the best candidate info.
#===========================================================================
func evaluate_local_candidates(ray_start: Vector2, nav_direction: Vector2) -> Dictionary:
	var best_score: float = -1.0
	var best_direction: Vector2 = nav_direction
	var best_index: int = -1
	var candidate_scores: Array[float] = []
	raycast_results.clear()

	for i: int in range(ray_directions.size()):
		var direction: Vector2 = ray_directions[i]
		# Base score based on how aligned the candidate is with the nav direction
		var score: float = (nav_direction.dot(direction) + 1.0) / 2.0

		# Raycast to detect obstacles.
		var result: Dictionary = _is_direction_blocked(ray_start, direction)
		raycast_results.append(result)

		# If an obstacle is detected, apply a penalty
		if not result.is_empty():
			var distance: float = ray_start.distance_to(result["position"])
			var penalty: float = (local_avoidance_range - distance) / local_avoidance_range
			score *= clamp(1.0 - penalty, 0.0, 1.0)

		# Preserve momentum: penalize if the candidate is 120º or more different in angle
		if last_movement_direction.dot(direction) < -0.5:
			score *= momentum_penalty_mult

		candidate_scores.append(score)
		if score > best_score:
			best_score = score
			best_direction = direction
			best_index = i

	last_candidate_scores = candidate_scores.duplicate()
	return {
		"best_direction": best_direction,
		"best_index": best_index,
		"candidate_scores": candidate_scores
	}

#===========================================================================
# Step 3: Check if the best candidate has adequate clearance.
#===========================================================================
func is_candidate_clear(best_index: int, candidate_scores: Array, ray_start: Vector2) -> bool:
	if best_index == -1:
		return false

	var candidate_clear: bool = false
	var best_result: Dictionary = raycast_results[best_index]
	if best_result.is_empty():
		candidate_clear = true
	else:
		var hit_distance: float = ray_start.distance_to(best_result["position"])
		candidate_clear = (hit_distance >= candidate_clearance_threshold)

	# Check adjacent candidate scores (to avoid narrow gaps)
	var left_index: int = best_index - 1
	var right_index: int = best_index + 1
	if left_index < 0:
		left_index = ray_directions.size() - 1
	if right_index >= ray_directions.size():
		right_index = 0

	# If scores to the left or right are low enough, this direction is not clear and is most likely peering around a corner or through a gap
	if candidate_scores[left_index] < 0.5 or candidate_scores[right_index] < 0.5:
		candidate_clear = false

	return candidate_clear

#===========================================================================
# Step 4: Compute an extra avoidance force from nearby obstacles.
#===========================================================================
func compute_avoidance_force(ray_start: Vector2, best_index: int) -> Vector2:
	var avoidance_force: Vector2 = Vector2.ZERO

	# Calculate the neighbor indices with wrap-around.
	var left_index: int = (best_index - 1 + ray_directions.size()) % ray_directions.size()
	var right_index: int = (best_index + 1) % ray_directions.size()

	var best_blocked: bool = false

	# --- Check best direction ---
	var best_result: Dictionary = raycast_results[best_index]
	if not best_result.is_empty():
		var best_distance: float = ray_start.distance_to(best_result["position"])
		if best_distance < local_avoidance_range * 0.5:
			best_blocked = true
			var best_strength: float = (local_avoidance_range - best_distance) / local_avoidance_range
			avoidance_force += -ray_directions[best_index] * best_strength

	# --- Check neighbor directions ---
	var neighbor_blocked_count: int = 0
	for index: int in [left_index, right_index]:
		var result: Dictionary = raycast_results[index]
		if not result.is_empty():
			var distance: float = ray_start.distance_to(result["position"])
			if distance < local_avoidance_range * 0.5:
				neighbor_blocked_count += 1
				var strength: float = (local_avoidance_range - distance) / local_avoidance_range
				avoidance_force += -ray_directions[index] * strength

	# --- Amplify if best is clear but both neighbors are blocked ---
	if (not best_blocked) and (neighbor_blocked_count == 2):
		avoidance_force *= 1.5  # Increase the repulsion force to account for the narrow gap.

	return avoidance_force

#===========================================================================
# Step 5: Blend in target behavior such as approaching, orbiting, or retreating.
#===========================================================================
func apply_target_behavior(global_nav: Vector2) -> Vector2:
	if target == null:
		return global_nav

	# Compute a normalized vector pointing toward the target.
	var to_target: Vector2 = target.global_position - entity.global_position
	if to_target == Vector2.ZERO:
		return global_nav  # Avoid division by zero.
	var target_direction: Vector2 = to_target.normalized()
	var orbit_vector: Vector2 = target_direction.rotated(behavior.orbit_dir * deg_to_rad(90))

	# --- Dynamic Weighting Based on Desired Target Distance ---
	var distance_to_target: float = entity.global_position.distance_to(target.global_position)
	var ratio: float = clamp(distance_to_target / behavior.desired_target_dist, 0.0, 2.0)
	# ratio == 1.0: target is exactly at desired distance.
	# ratio > 1.0: target is farther than desired; boost the approach.
	# ratio < 1.0: target is too close; boost the retreat.
	var approach_factor: float = 1.0
	var retreat_factor: float = 1.0

	if ratio < 1.0:
		# When too close, weaken the approach and increase retreat.
		approach_factor = ratio
		retreat_factor = 1.0 + (1.0 - ratio)
	else:
		# When too far, strengthen the approach.
		approach_factor = 1.0 + (ratio - 1.0)
		retreat_factor = 1.0

	# --- Combine the Behavior Components ---
	# The orbit component can remain as assigned.
	var behavior_vector: Vector2 = (behavior.approach_weight * approach_factor * target_direction) + (behavior.orbit_weight * orbit_vector) + (behavior.retreat_weight * retreat_factor * (-target_direction))
	behavior_vector = behavior_vector.normalized()

	# --- Blend Behavior with Global Navigation ---
	# behavior_blend of 0 means purely global nav,
	# 1 means completely follow target behavior.
	var modified_global: Vector2 = ((1.0 - behavior.behavior_blend) * global_nav + behavior.behavior_blend * behavior_vector).normalized()

	return modified_global

#===========================================================================
# Step 6: Apply dynamic smoothing based on the last movement direction.
#===========================================================================
func apply_dynamic_smoothing(preliminary_direction: Vector2, current_direction: Vector2) -> Vector2:
	var angle_diff: float = current_direction.angle_to(preliminary_direction)
	var dynamic_smoothing: float = smoothing_factor
	if angle_diff > deg_to_rad(45):
		dynamic_smoothing *= 0.5
	return current_direction.lerp(preliminary_direction, dynamic_smoothing)
#endregion

func get_should_sprint() -> bool:
	return false

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

## When the stun timer ends, notify that we can return to Idle if needed, but check if we
## have enemies in range first.
func _on_stun_timer_timeout() -> void:
	fsm.change_state("idle")
	_on_enemies_in_range_changed()

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

func notify_spawn_ended() -> void:
	fsm.change_state("idle")
	_on_enemies_in_range_changed()

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
