extends Camera2D
class_name PlayerCamera

@export var player: Player
@export var smoothing_enabled: bool = false
@export_range(1, 100, 1) var smoothing_factor: int = 7
@export var drag_vertical: float = 0.1
@export var drag_horizontal: float = 0.2

var shake_strength: float = 0
var shake_time: float = 0
var shake_tween: Tween = null
const MAX_SHAKE_STRENGTH: float = 30.0
const MAX_SHAKE_TIME: float = 2.0


func _ready() -> void:
	global_position = player.global_position

func _physics_process(delta: float) -> void:
	if shake_strength > 0:
		offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	if shake_time > 0:
		shake_time -= delta

	if player != null:
		if smoothing_enabled:
			var camera_pos: Vector2 = global_position
			var screen_size = get_viewport_rect().size
			var vertical_limit = screen_size.y * drag_vertical
			var horizontal_limit = screen_size.x * drag_horizontal
			var player_screen_pos = to_local(player.global_position)

			# Check vertical threshold
			if player_screen_pos.y < -vertical_limit:
				camera_pos.y = lerp(camera_pos.y, player.global_position.y + vertical_limit, float(smoothing_factor) * delta)
			elif player_screen_pos.y > vertical_limit:
				camera_pos.y = lerp(camera_pos.y, player.global_position.y - vertical_limit, float(smoothing_factor) * delta)

			# Check horizontal threshold
			if player_screen_pos.x > horizontal_limit:
				camera_pos.x = lerp(camera_pos.x, player.global_position.x - horizontal_limit, float(smoothing_factor) * delta)
			elif player_screen_pos.x < -horizontal_limit:
				camera_pos.x = lerp(camera_pos.x, player.global_position.x + horizontal_limit, float(smoothing_factor) * delta)

			global_position = camera_pos
		else:
			global_position = player.global_position

## Starts a camera shake effect that can be stacked with already existing effects if they are still running.
func start_shake(strength: float, shake_duration: float) -> void:
	if shake_duration > 0:
		shake_time = min(MAX_SHAKE_TIME, shake_time + shake_duration)
		shake_strength = min(MAX_SHAKE_STRENGTH, shake_strength + strength)

		if shake_tween:
			shake_tween.stop()
			shake_tween.kill()
		shake_tween = create_tween()
		shake_tween.tween_property(self, "shake_strength", 0.0, shake_time)

## Starts a freeze/slow effect for the whole engine.
func start_freeze(time_multiplier: float, freeze_duration: float) -> void:
	if freeze_duration > 0 and Engine.time_scale == 1.0:
		Engine.time_scale = time_multiplier
		await get_tree().create_timer(freeze_duration, false, false, true).timeout
		Engine.time_scale = 1.0
