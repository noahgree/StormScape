extends DynamicController
class_name DynamicAIController
## This subclass handles controlling dynamic AI entities such as enemies and player ally AI.

@export var path_delay_minmax: Vector2 = Vector2(0.5, 1.0) ## X is the min path recalc delay, Y is the max.
@export var raycast_length: float = 25.0 ## How far to scan for local obstacles.
@export var global_weight: float = 0.4 ## The importance of the global nav agent path in the final direction.
@export var local_weight: float = 0.6 ## The importance of the local obstacle detection in the final direction.

var nav_agent: NavigationAgent2D ## The global nav agent.
var detector: DetectionComponent
var should_sprint: bool = false
var target: PhysicsBody2D = null
var path_recalc_timer: Timer = TimerHelpers.create_repeating_timer(self, -1, _calculate_path_to_target)
var raycast_results: Array[Dictionary] = []
var debug_recent_movement_dir: Vector2
var fallback_dir: Vector2
var fallback_dir_recalc_counter: float = 1.5
var ray_directions: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(1, 1).normalized(),
	Vector2(-1, 1).normalized(),
	Vector2(1, -1).normalized(),
	Vector2(-1, -1).normalized()
]


#region Debug
func _draw() -> void:
	if not DebugFlags.show_collision_avoidance_rays:
		return
	for i: int in range(raycast_results.size()):
		var result: Dictionary = raycast_results[i]
		var direction: Vector2 = ray_directions[i]
		var ray_end: Vector2 = entity.global_position + (direction * raycast_length)

		if result.size() > 0:
			var hit_position: Vector2 = result["position"]
			draw_line(entity.global_position, hit_position, Color.RED, 0.5)
			draw_circle(hit_position, 1.25, Color.RED)
		else:
			draw_line(entity.global_position, ray_end, Color.GREEN, 0.25)

	if not DebugFlags.show_movement_vector:
		return
	var movement_vector_end: Vector2 = entity.global_position + (debug_recent_movement_dir * 35)
	draw_line(entity.global_position, movement_vector_end, Color.YELLOW, 0.75)
#endregion

func setup() -> void:
	super.setup()

	nav_agent = entity.get_node("NavigationAgent2D")
	detector = entity.detection_component
	detector.enemies_in_range_changed.connect(_on_enemies_in_range_changed)
	await get_tree().physics_frame
	_on_enemies_in_range_changed(detector.enemies_in_range)

func controller_process(delta: float) -> void:
	super.controller_process(delta)

	entity.facing_component.update_facing_dir(FacingComponent.Method.TARGET_POS)
	fallback_dir_recalc_counter = max(0, fallback_dir_recalc_counter - delta)
	if fallback_dir_recalc_counter <= 0:
		fallback_dir_recalc_counter = 1.5
		fallback_dir = VectorHelpers.get_random_direction()

#region Inputs
func get_movement_vector() -> Vector2:
	var avoidance_vector: Vector2 = Vector2.ZERO
	var obstacle_count: int = 0

	raycast_results.clear()
	for direction: Vector2 in ray_directions:
		var ray_end: Vector2 = entity.global_position + (direction * raycast_length)
		if _is_obstacle_in_path(entity.global_position, ray_end):
			obstacle_count += 1
			var result: Dictionary = raycast_results.back()
			var distance: float = entity.global_position.distance_to(result["position"])
			var weight: float = (raycast_length - distance) / raycast_length
			avoidance_vector -= direction * max(0.5, weight)

	var path_direction: Vector2 = entity.to_local(nav_agent.get_next_path_position()).normalized()

	# Prioritize path direction more heavily
	var dir_with_avoidance: Vector2 = (path_direction * 0.6 + avoidance_vector * 0.4).normalized()

	# Fallback mechanism: if stuck, apply a small random push
	if obstacle_count > 1:
		dir_with_avoidance += fallback_dir
		dir_with_avoidance = dir_with_avoidance.normalized()

	queue_redraw()

	var final_move_dir: Vector2 = dir_with_avoidance.rotated(entity.stats.get_stat("confusion_amount"))
	debug_recent_movement_dir = final_move_dir
	return final_move_dir

func get_should_sprint() -> bool:
	return should_sprint
#endregion

func _is_obstacle_in_path(ray_start: Vector2, ray_end: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [entity.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	raycast_results.append(result)
	return result.size() > 0

func _on_enemies_in_range_changed(enemies_in_range: Array[PhysicsBody2D]) -> void:
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
