extends Sprite2D
class_name DashGhost
## A simple sprite2D node to handle fading and queue freeing a ghost instance during something like a dash state.

var fade_out_time: float = 0.0 ## How long the sprite takes to fade out after being instanced.


## Takes in relevant data to instance the node in the world as a ghost, including a custom fade out time.
func init(pos: Vector2, size: Vector2, frame: Texture2D, fade_time: float) -> void:
	position = pos
	scale = size
	if frame:
		texture = frame
	fade_out_time = fade_time
	self_modulate = Color(1, 1, 1, 0.6)

func _ready() -> void:
	_do_ghosting()

## Creates the tween for handling the fade out, waits for the fade to finish, then queue frees the node.
func _do_ghosting() -> void:
	var fade_out_tween: Tween = create_tween()
	fade_out_tween.tween_property(self, "self_modulate", Color(1, 1, 1, 0), fade_out_time)
	
	await fade_out_tween.finished
	queue_free()
