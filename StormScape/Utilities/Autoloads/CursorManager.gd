extends CanvasLayer
## This singleton manages the game's cursor and its behavior in certain instances like getting too close to the player.

@onready var cursor: AnimatedSprite2D = $Cursor ## The animated sprite node responsible for displaying the cursor.
@onready var default_cursor: SpriteFrames = cursor.sprite_frames ## The default sprite frames used as the cursor when one isn't specified.

var previous_angle: float = 0 ## The angle of the cursor relative to the player as of the last frame. Used for lerping.
var restore_after_hitmarker_countdown: float = 0 ## Counts down after being changed to the hitmarker cursor before restoring the default.
const MAX_PROXIMITY_TO_CHAR: float = 8.0 ## The closest number of pixels the mouse can be to the origin of the player before being clamped.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(delta: float) -> void:
	var mouse_position: Vector2 = cursor.get_global_mouse_position()
	var entity_position: Vector2 = GlobalData.player_node.hands.hands_anchor.global_position
	var to_mouse_vector: Vector2 = mouse_position - entity_position

	if to_mouse_vector.length() < MAX_PROXIMITY_TO_CHAR:
		var target_angle: float = to_mouse_vector.angle()
		var new_angle: float = lerp_angle(previous_angle, target_angle, 0.15)

		var clamped_position: Vector2 = entity_position + Vector2.RIGHT.rotated(new_angle) * MAX_PROXIMITY_TO_CHAR
		cursor.global_position = clamped_position
		previous_angle = new_angle
	else:
		# Directly set the position when not clamping
		cursor.global_position = entity_position + to_mouse_vector
		previous_angle = to_mouse_vector.angle()

	if restore_after_hitmarker_countdown > 0:
		restore_after_hitmarker_countdown -= delta
		if restore_after_hitmarker_countdown <= 0:
			cursor.play(&"default")

## Should be used everywhere in the game that needs to access the global mouse position.
## This is becuase the fake cursor's position can be lerped at times and is all that is visible.
func get_cursor_mouse_position() -> Vector2:
	return cursor.global_position

## Called to reset the cursor visuals.
func reset() -> void:
	change_cursor(default_cursor)
	update_vertical_tint_progress(100.0)

## Changes the cursor animation. If null is passed in instead of a sprite frames resource, the old cursor will remain.
func change_cursor(sprite_frames: SpriteFrames, animation: StringName = &"default", tint: Color = Color.WHITE) -> void:
	update_vertical_tint_progress(100.0)

	if sprite_frames != null:
		cursor.sprite_frames = sprite_frames
	if cursor.sprite_frames.has_animation(animation):
		if animation == "hit":
			restore_after_hitmarker_countdown = 0.08
		cursor.play(animation)
	else:
		cursor.play(&"default")
	change_cursor_tint(tint)

## Updates the cursor's tint.
func change_cursor_tint(tint: Color) -> void:
	cursor.set_instance_shader_parameter("main_color", tint)

func get_cursor_tint() -> Color:
	return cursor.get_instance_shader_parameter("main_color")

## Updates the shader controlling the vertical fill progress.
func update_vertical_tint_progress(value: float) -> void:
	cursor.set_instance_shader_parameter("progress", clampf(value, 0.0, 100.0))
