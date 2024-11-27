extends Marker2D
class_name EffectPopup
## The popup that displays briefly after an effect source is applied. Shows things like the applied damage or healing values.

enum PopupTypes {
	SHIELD_DMG, HEALTH_DMG, CRIT_DMG, SHIELD_HEAL, HEALTH_HEAL
}

static var popup_scene: PackedScene = load("res://UI/TemporaryElements/EffectPopup.tscn") ## The popup scene to be instantiated when a popup is created above something.

@export var shield_dmg_color: Color = Color(0.793, 0.49, 1)
@export var health_dmg_color: Color = Color(1, 1, 1)
@export var crit_dmg_color: Color = Color(1.546, 1.0, 0)
@export var shield_heal_color: Color = Color(0.793, 0.49, 1)
@export var health_heal_color: Color = Color(1, 1, 1)

@onready var number_label: Label = $NumberLabel
@onready var glow: TextureRect = $Glow

var type: PopupTypes = PopupTypes.SHIELD_DMG
var value: int = 0


static func create_popup(popup_type: EffectPopup.PopupTypes, popup_value: int, node: PhysicsBody2D) -> void:
	var popup: EffectPopup = popup_scene.instantiate()

	popup.type = popup_type
	popup.value = popup_value

	popup.global_position = node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(node.sprite).y)
	GlobalData.world_root.add_child(popup)

func _ready() -> void:
	number_label.text = str(value)
	position.x += (randf_range(-4.5, 4.5))
	glow.scale.x = max(0.04, 0.02 * str(value).length())
	glow.position.x = min(-10.588, -5.294 * str(value).length())

	match type:
		PopupTypes.SHIELD_DMG:
			number_label.add_theme_color_override("font_color", shield_dmg_color)
		PopupTypes.HEALTH_DMG:
			number_label.add_theme_color_override("font_color", health_dmg_color)
		PopupTypes.CRIT_DMG:
			number_label.add_theme_color_override("font_color", crit_dmg_color)
			scale *= 1.15
		PopupTypes.SHIELD_HEAL:
			number_label.add_theme_color_override("font_color", shield_heal_color)
			number_label.text = "+" + number_label.text
			glow.modulate = Color(0.12, 0.92, 0.0, 1.0)
		PopupTypes.HEALTH_HEAL:
			number_label.add_theme_color_override("font_color", health_heal_color)
			number_label.text = "+" + number_label.text
			glow.modulate = Color(0.12, 0.92, 0.0, 1.0)

	_tween_self()

## Tweens the animated properties of the popup then frees it.
func _tween_self() -> void:
	var tween: Tween = create_tween()

	tween.tween_property(self, "scale", scale * 1.25, 0.1).set_trans(Tween.TRANS_SPRING)
	tween.parallel().tween_property(self, "skew", 0.0, 0.1)
	tween.parallel().tween_property(self, "position", position + Vector2(2, 2), 0.05)

	tween.tween_interval(0.1)

	tween.chain().tween_property(self, "global_position", global_position + Vector2(0, -5), 0.2)
	tween.parallel().tween_property(self, "scale", scale * 0.5, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.35, 0.2)
	tween.parallel().tween_property(self, "skew", deg_to_rad(5.0), 0.2)
	tween.chain().tween_callback(queue_free)
