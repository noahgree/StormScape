extends Sprite2D
class_name DashGhost


var fade_out_time: float = 0.0


func init(pos: Vector2, size: Vector2, frame: Texture2D, fade_time: float) -> void:
	position = pos
	scale = size
	if frame:
		texture = frame
	fade_out_time = fade_time
	self_modulate = Color(1, 1, 1, 0.6)

func _ready() -> void:
	do_ghosting()

func do_ghosting() -> void:
	var fade_out_tween: Tween = create_tween()
	fade_out_tween.tween_property(self, "self_modulate", Color(1, 1, 1, 0), fade_out_time)
	
	await fade_out_tween.finished
	queue_free()
