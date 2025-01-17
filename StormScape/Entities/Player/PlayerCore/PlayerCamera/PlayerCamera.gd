extends Camera2D
class_name PlayerCamera
## The main player camera that implements screen shake and engine freeze/slow.

@export var player: Player ## A reference to the player.
@export var smoothing_enabled: bool = false ## Whether to use smoothing logic when this camera moves.
@export_range(1, 100, 1) var smoothing_factor: int = 7 ## The amount of smoothing to use.
@export var drag_vertical: float = 0.1 ## The vertical ratio of screen to allow shown ahead of the player before moving the camera.
@export var drag_horizontal: float = 0.2 ## The horizontal ratio of screen to allow shown ahead of the player before moving the camera.

var current_shake_strength: float = 0 ## The current shake strength of the camera. Automatically decremented over time once set.
var current_shake_time: float = 0 ## How long the shake strength should take to return to 0.
var shake_tween: Tween = null ## Tween for automatically decreasing the camera shake strength.
var freeze_tween: Tween = null ## Tween for automatically decreasing the camera freeze multiplier.
var current_freeze_time: float = 0 ## How long the freeze multiplier should take to return to 1.0.
var zoom_tween: Tween = null ## Tween for automatically bringing the camera zoom multiplier back to normal.
var current_zoom_time: float = 0 ## How long the zoom multiplier should take to return to 1.0.


## Sets the initial position to be right above the player.
func _ready() -> void:
	global_position = player.global_position

## Runs positioning logic for every physics frame. Also checks if shake is needed and automatically decrements it.
func _physics_process(delta: float) -> void:
	if current_shake_strength > 0:
		offset = Vector2(randf_range(-current_shake_strength, current_shake_strength), randf_range(-current_shake_strength, current_shake_strength))

	if current_shake_time > 0:
		current_shake_time = max(0, current_shake_time - delta)
	if current_zoom_time > 0:
		current_zoom_time = max(0, current_zoom_time - delta)

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

## Starts a camera shake effect for the player camera.
func start_shake(fx_resource: CamFXResource) -> void:
	if fx_resource.shake_duration <= 0 or fx_resource.shake_strength <= 0:
		return

	if fx_resource.shake_strength > current_shake_strength:
		current_shake_strength = fx_resource.shake_strength
		current_shake_time = max(0.03, max(fx_resource.shake_duration, current_shake_time))

		if shake_tween:
			shake_tween.stop()
			shake_tween.kill()
		shake_tween = create_tween().set_trans(fx_resource.shake_trans_type).set_ease(fx_resource.shake_ease_type)
		shake_tween.tween_property(self, "current_shake_strength", 0.0, current_shake_time)

## Starts a freeze/slow effect for the whole engine.
func start_freeze(fx_resource: CamFXResource) -> void:
	if fx_resource.freeze_multiplier >= 1.0:
		return

	if fx_resource.freeze_multiplier < Engine.time_scale:
		Engine.time_scale = max(0.01, fx_resource.freeze_multiplier)
		current_freeze_time = max(0.03, max(fx_resource.freeze_duration, current_freeze_time))

		if freeze_tween:
			freeze_tween.stop()
			freeze_tween.kill()

		freeze_tween = create_tween()
		freeze_tween.set_trans(fx_resource.freeze_trans_type).set_ease(fx_resource.freeze_ease_type).set_ignore_time_scale(true)
		freeze_tween.tween_property(Engine, "time_scale", 1.0, current_freeze_time)

## Starts a zoom effect for the player camera.
func start_zoom(fx_resource: CamFXResource) -> void:
	if fx_resource.zoom_duration <= 0 or fx_resource.zoom_multiplier == zoom.x:
		return

	current_zoom_time = max(0.04, max(fx_resource.zoom_duration, current_zoom_time))

	if zoom_tween:
		zoom_tween.stop()
		zoom_tween.kill()

	zoom_tween = create_tween().set_trans(fx_resource.zoom_trans_type).set_ease(fx_resource.zoom_ease_type)

	zoom_tween.tween_property(self, "zoom", Vector2(fx_resource.zoom_multiplier, fx_resource.zoom_multiplier), current_zoom_time / 2.0)
	zoom_tween.tween_property(self, "zoom", Vector2(1.0, 1.0), current_zoom_time / 2.0)
