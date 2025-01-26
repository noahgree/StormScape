extends DynamicController
class_name DynamicAIController
## This subclass handles controlling dynamic AI entities such as enemies and player ally AI.

@export var path_recalc_delay: float = 1.0

@onready var nav_agent: NavigationAgent2D = entity.get_node("NavigationAgent2D")

var detector: DetectionComponent
var should_sneak: bool = false
var should_sprint: bool = false
var target: PhysicsBody2D = null
var path_timer: Timer = TimerHelpers.create_repeating_timer(self, path_recalc_delay, _calculate_path_to_target)


func _ready() -> void:
	super._ready()

	if not entity.is_node_ready():
		await entity.ready
	detector = entity.detection_component
	detector.enemies_in_range_changed.connect(_on_enemies_in_range_changed)

	await get_tree().physics_frame
	_on_enemies_in_range_changed(detector.enemies_in_range)

func controller_process(delta: float) -> void:
	super.controller_process(delta)

	entity.facing_component.update_facing_dir(FacingComponent.Method.TARGET_POS)

#region Inputs
func get_movement_vector() -> Vector2:
	var dir: Vector2 = entity.to_local(nav_agent.get_next_path_position()).normalized()
	return (dir.rotated(entity.stats.get_stat("confusion_amount")))

func get_should_sprint() -> bool:
	return should_sprint

func get_should_sneak() -> bool:
	return should_sneak
#endregion

func _on_enemies_in_range_changed(enemies_in_range: Array[PhysicsBody2D]) -> void:
	if enemies_in_range.is_empty():
		target = null
		notify_no_enemies_in_range()
	else:
		if target not in enemies_in_range:
			target = null
			_determine_target()

		notify_enemy_in_range()

## When the stun timer ends, notify that we can return to Idle if needed, but check if we
## have enemies in range first.
func _on_stun_timer_timeout() -> void:
	if detector.enemies_in_range.is_empty():
		notify_stopped_moving()
	else:
		notify_enemy_in_range()

## Requests to add a value to the current knockback vector, doing so if possible.
func notify_requested_knockback(knockback: Vector2) -> void:
	match fsm.current_state.name:
		"Sneak", "Idle", "Stunned", "Chase":
			knockback_vector = (knockback_vector + knockback).limit_length(MAX_KNOCKBACK)
			reset_and_create_knockback_streak()

func notify_spawn_ended() -> void:
	fsm.change_state("Idle")

	if detector.enemies_in_range.is_empty():
		notify_stopped_moving()
	else:
		notify_enemy_in_range()

func notify_no_enemies_in_range() -> void:
	match fsm.current_state.name:
		"Chase":
			fsm.change_state("Idle")

func notify_enemy_in_range() -> void:
	match fsm.current_state.name:
		"Idle":
			_determine_target()
			fsm.change_state("Chase")

func _determine_target() -> void:
	var num_targets: int = detector.enemies_in_range.size()
	if num_targets == 0:
		return

	target = detector.enemies_in_range[randi_range(0, num_targets - 1)]
	_calculate_path_to_target()

func _calculate_path_to_target() -> void:
	if target == null:
		return

	nav_agent.target_position = target.global_position
	path_timer.start()
