extends MarginContainer
class_name HUDMessage
## Spawnable messages sent to appear in the queue of the message manager.

@onready var text_label: RichTextLabel = %TextLabel ## The label that shows the text of the message.
@onready var message_icon: TextureRect = %MessageIcon ## The icon texture rect.
@onready var content_root: MarginContainer = %ContentRoot ## This is what the tween moves.

var lifetime_timer: Timer = TimerHelpers.create_one_shot_timer(self, 1.0, _on_lifetime_end, "LifetimeTimer") ## Tracks lifetime of the message.

## Sets the details of the message after it has been created by the manager.
func set_details(text: String, text_color: Color, icon: Texture2D, icon_color: Color, display_time: float) -> void:
	text_label.text = text
	text_label.add_theme_color_override("default_color", text_color)
	message_icon.texture = icon
	message_icon.modulate = icon_color

	lifetime_timer.start(display_time)


func _ready() -> void:
	content_root.modulate.a = 0
	await get_tree().process_frame
	var final_pos: float = content_root.position.x

	content_root.position.x += 50
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(content_root, "position:x", final_pos, 0.2)
	tween.parallel().tween_property(content_root, "modulate:a", 1.0, 0.2)

## When the lifetime ends, tween it out and queue free it.
func _on_lifetime_end() -> void:
	var tween: Tween = create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(content_root, "position:x",  content_root.position.x + 100, 0.2)
	tween.parallel().tween_property(content_root, "modulate:a", 0, 0.2)
	tween.tween_callback(queue_free)
