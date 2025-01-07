extends Camera2D
class_name PlayerCamera
## The main player camera that implements screen shake and engine freeze/slow.

@export var player: Player ## A reference to the player.
@export var smoothing_enabled: bool = false ## Whether to use smoothing logic when this camera moves.
@export_range(1, 100, 1) var smoothing_factor: int = 7 ## The amount of smoothing to use.
@export var drag_vertical: float = 0.1 ## The vertical ratio of screen to allow shown ahead of the player before moving the camera.
@export var drag_horizontal: float = 0.2 ## The horizontal ratio of screen to allow shown ahead of the player before moving the camera.

var shake_strength: float = 0 ## The current shake strength of the camera. Automatically decremented over time once set.
var persistent_shake_strength: float = 0 ## The amount of persistent strength that must be manually removed and does not lerp down.
var shake_time: float = 0 ## How long the shake strength should take to return to 0. Can be updated on the fly.
var shake_tween: Tween = null ## Tween for automatically decreasing the camera shake strength.
const MAX_SHAKE_STRENGTH: float = 25.0 ## The max amount of cumulative shake strength this camera can have at any given time.
const MAX_SHAKE_TIME: float = 2.0 ## The max amount of cumulative shake time this camera can have at any given point.


## Sets the initial position to be right above the player.
func _ready() -> void:
	global_position = player.global_position

## Runs positioning logic for every physics frame. Also checks if shake is needed and automatically decrements it.
func _physics_process(delta: float) -> void:
	if shake_strength + persistent_shake_strength > 0:
		var strength: float = shake_strength + persistent_shake_strength
		offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))

	if shake_time > 0:
		shake_time = max(0, shake_time - delta)

	if player != null:
		if smoothing_enabled:
			var camera_pos: Vector2 = global_position
			var screen_size: Vector2 = get_viewport_rect().size
			var vertical_limit: float = screen_size.y * drag_vertical
			var horizontal_limit: float = screen_size.x * drag_horizontal
			var player_screen_pos: Vector2 = to_local(player.global_position)

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
func start_shake(strength: float, duration: float) -> void:
	if duration <= 0 or strength <= 0:
		return

	var clamped_strength: float = clampf(strength, 0, MAX_SHAKE_STRENGTH)
	var clamped_time: float = clampf(max(duration, shake_time), 0.05, MAX_SHAKE_TIME)

	if clamped_strength > shake_strength:
		shake_strength = clamped_strength
		shake_time = clamped_time

	if shake_tween:
		shake_tween.stop()
		shake_tween.kill()
	shake_tween = create_tween()
	shake_tween.tween_property(self, "shake_strength", 0.0, shake_time)

## Updates the persistent shake strength that does not decrease over time.
func update_persistent_shake_strength(strength: float) -> void:
	persistent_shake_strength = clampf(persistent_shake_strength + strength, 0, MAX_SHAKE_STRENGTH)

## Resets the persistent shake strength back to 0.
func reset_persistent_shake_strength() -> void:
	persistent_shake_strength = 0

## Starts a freeze/slow effect for the whole engine.
func start_freeze(time_multiplier: float, freeze_duration: float) -> void:
	if freeze_duration > 0 and Engine.time_scale == 1.0 and time_multiplier < 1.0:
		Engine.time_scale = time_multiplier
		await get_tree().create_timer(freeze_duration, false, false, true).timeout
		Engine.time_scale = 1.0
