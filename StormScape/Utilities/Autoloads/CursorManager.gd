extends CanvasLayer
## This singleton manages the game's cursor and its behavior in certain instances like getting too close to the player.

@onready var cursor: AnimatedSprite2D = $Cursor ## The animated sprite node responsible for displaying the cursor.

var previous_angle: float = 0 ## The angle of the cursor relative to the player as of the last frame. Used for lerping.
var default_cursor: SpriteFrames ## The default sprite frames used as the cursor when one isn't specified.


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	default_cursor = cursor.sprite_frames

func _process(_delta: float) -> void:
	var mouse_position: Vector2 = cursor.get_global_mouse_position()
	var entity_position: Vector2 = GlobalData.player_node.hands.hands_anchor.global_position
	var to_mouse_vector: Vector2 = mouse_position - entity_position

	if to_mouse_vector.length() < 5.0:
		var target_angle: float = to_mouse_vector.angle()
		var new_angle: float = lerp_angle(previous_angle, target_angle, 0.15)

		var clamped_position: Vector2 = entity_position + Vector2.RIGHT.rotated(new_angle) * 5.0
		cursor.global_position = clamped_position
		previous_angle = new_angle
	else:
		# Directly set the position when not clamping
		cursor.global_position = entity_position + to_mouse_vector
		previous_angle = to_mouse_vector.angle()

## Should be used everywhere in the game that needs to access the global mouse position.
## This is becuase the fake cursor's position can be lerped at times and is all that is visible.
func get_cursor_mouse_position() -> Vector2:
	return cursor.global_position

## Changes the cursor animation. If null is passed in instead of a sprite frames resource, the old cursor will remain.
func change_cursor(sprite_frames: SpriteFrames, tint: Color) -> void:
	if sprite_frames != null:
		cursor.sprite_frames = sprite_frames
	cursor.modulate = tint
