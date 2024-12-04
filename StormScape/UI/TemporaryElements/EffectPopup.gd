extends Marker2D
class_name EffectPopup
## The popup that displays briefly after an effect source is applied. Shows things like the applied damage or healing values.

static var popup_scene: PackedScene = load("res://UI/TemporaryElements/EffectPopup.tscn") ## The popup scene to be instantiated when a popup is created above something.

@export var text_colors: Dictionary = { ## The strings that have associated colors to change the text color to.
	"Frostbite" : [Color(0.591, 0.884, 1), Color(0, 0.6, 0.933)],
	"Burning" : [Color(1, 0.284, 0.25), Color(0.969, 0.694, 0)],
	"Poison" : [Color(0, 0.933, 0.469), Color(0, 0.933, 0.469)],
	"Storm Syndrome" : [Color(1, 0.328, 0.899), Color(0.765, 0.654, 1)],
	"Regen" : [Color(0, 0.853, 0.283), Color(0, 0.834, 0.62)],
	"Life Steal" : [Color(0, 0.74, 0.554), Color(1, 0.4, 0.463)],
	"CritDamage" : [Color(2.0, 0.7, 0.1), Color(1.4, 1.25, 0.9)],
	"ShieldDamage" : [Color(0.751, 0.403, 1), Color(0.751, 0.403, 1)],
	"HealthDamage" : [Color(1, 0.274, 0.32), Color(1, 0.274, 0.32)],
}

@onready var number_label: Label = $NumberLabel
@onready var glow: TextureRect = $Glow

var source_type: String
var is_healing: bool
var value: int = 0


static func create_popup(src_type: String, was_healing: bool, popup_value: int, node: PhysicsBody2D) -> void:
	var popup: EffectPopup = popup_scene.instantiate()

	popup.source_type = src_type
	popup.value = popup_value
	popup.is_healing = was_healing

	popup.global_position = node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(node.sprite).y)
	GlobalData.world_root.add_child(popup)

func _ready() -> void:
	number_label.text = str(value)
	position.x += (randf_range(-4.5, 4.5))

	var gradient_texture = number_label.material.get_shader_parameter("gradient_texture")
	var gradient = gradient_texture.gradient

	for i in range(gradient.get_point_count()):
		var current_color = gradient.get_color(i)
		var new_color: Color = text_colors.get(source_type, [Color(1, 1.0, 1.0), Color(1, 1.0, 1.0)])[i]
		gradient.set_color(i, new_color)

	print(source_type)

	number_label.material.set_shader_parameter("gradient_texture", gradient_texture)

	if is_healing:
		glow.modulate = Color(0.1, 0.90, 0.0, 1.0)
		number_label.text = "+" + number_label.text
	else:
		glow.modulate = Color(1.25, 0.2, 0.3, 1.0)
	if source_type == "CritDamage": scale *= 1.15

	glow.scale.x = max(0.062, 0.031 * str(value).length())
	glow.position.x = min(-14.75, -7.375 * str(value).length())

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
