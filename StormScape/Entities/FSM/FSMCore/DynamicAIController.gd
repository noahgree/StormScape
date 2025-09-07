extends DynamicController
class_name DynamicAIController
## This subclass handles controlling dynamic AI entities such as enemies and player ally AI.

@export_group("Setup")
@export var path_delay_minmax: Vector2 = Vector2(0.5, 1.0) ## X is the min path recalc delay, Y is the max.
@export var local_avoidance_range: float = 15.0 ## How far away from the entity to scan for local collisions.
@export var ray_start_offset: Vector2 = Vector2.ZERO ## How much to offset the starting point of the raycasts.

@export_group("Movement Behavior")
@export var behavior: MoveBehaviorResource = MoveBehaviorResource.new() ## The resource defining the current movement behavior weights.

var detector: DetectionComponent ## The detector component of the entity this is attached to, used to notify when enemies have entered or exited our detection range.
var target: Node2D ## The currently sought after target node.
var nav_manager: NavManager = NavManager.new(self) ## The script managing getting AI movement direction and targets.


#region Debug
func _draw() -> void:
	if not DebugFlags.show_nav:
		return

	var max_score: float = -100000
	var min_score: float = 100000
	for score: float in nav_manager.dir_interests:
		if score < min_score:
			min_score = score
		if score > max_score:
			max_score = score

	var ray_start: Vector2 = entity.global_position + ray_start_offset
	for i: int in range(nav_manager.raycast_results.size()):
		var result: Dictionary = nav_manager.raycast_results[i]
		var direction: Vector2 = nav_manager.ray_directions[i]
		var ray_end: Vector2 = ray_start + (direction * local_avoidance_range)

		var score: float = 0.0
		if i < nav_manager.dir_interests.size() and max_score != min_score:
			score = (nav_manager.dir_interests[i] - min_score) / (max_score - min_score)
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

	nav_manager.nav_agent = entity.get_node("NavigationAgent2D")
	detector = entity.detection_component
	detector.enemies_in_range_changed.connect(_on_enemies_in_range_changed)

	# Force check if we are in range of any enemies at spawn
	await get_tree().physics_frame
	_on_enemies_in_range_changed(detector.enemies_in_range)

## Called by the entity itself every frame.
func controller_process(delta: float) -> void:
	super(delta)
	entity.facing_component.update_facing_dir(facing_method)

## Returns the normalized direction in which the entity should move.
func get_movement_vector() -> Vector2:
	var move_vector: Vector2 = nav_manager.get_movement_vector()
	queue_redraw()
	return move_vector

## Determines if the state controlling the movement should use sprinting.
func get_should_sprint() -> bool:
	return false

## Called automatically when the detector component emits that the list of enemies in range has changed.
func _on_enemies_in_range_changed(enemies_in_range: Array[Entity] = detector.enemies_in_range) -> void:
	if enemies_in_range.is_empty():
		target = null
		nav_manager.path_recalc_timer.stop()
		match fsm.current_state.state_id:
			"chase", "knockback":
				fsm.change_state("idle")
	else:
		if target not in enemies_in_range:
			target = null
			nav_manager.determine_target()
		notify_enemy_in_range()
#endregion

## Gets the position to aim towards.
func get_aim_position() -> Vector2:
	#if target == null:
	return entity.global_position + (entity.facing_component.facing_dir * 25.0)
	#return target.global_position

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
			nav_manager.determine_target()
			if fsm.has_state("chase"):
				fsm.change_state("chase")
#endregion
