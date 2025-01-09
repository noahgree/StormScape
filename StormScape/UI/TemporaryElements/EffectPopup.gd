extends Marker2D
class_name EffectPopup
## The popup that displays briefly after an effect source is applied. Shows things like the applied damage or healing values.

static var popup_scene: PackedScene = load("res://UI/TemporaryElements/EffectPopup.tscn") ## The popup scene to be instantiated when a popup is created above something.
static var last_offset: float = 0

@export var text_colors: Dictionary[String, GradientTexture1D] ## The strings that have associated colors to change the text color to.

@onready var number_label: Label = $CenterContainer/NumberLabel
@onready var number_outline: Label = $CenterContainer/NumberOutline
@onready var glow: TextureRect = $CenterContainer/Glow
@onready var gradient_tex: TextureRect = $CenterContainer/NumberLabel/GradientTex

var starting_scale: Vector2
var starting_offset: float
var source_type: String
var is_healing: bool
var is_crit: bool
var value: int = 0
var parent_node: PhysicsBody2D
var tween: Tween


static func create_popup(src_type: String, was_healing: bool, was_crit: bool, popup_value: int, node: PhysicsBody2D) -> EffectPopup:
	var popup: EffectPopup = popup_scene.instantiate()

	popup.source_type = src_type
	popup.is_healing = was_healing
	popup.is_crit = was_crit
	popup.value = popup_value
	popup.parent_node = node

	if last_offset <= 0:
		last_offset = randf_range(0.5, 6)
	else:
		last_offset = randf_range(-6, -0.5)

	popup.global_position = node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(node.sprite).y)
	GlobalData.world_root.add_child(popup)
	return popup

func _ready() -> void:
	starting_scale = scale
	starting_offset = last_offset
	update_popup(0, is_crit)

func update_popup(new_value: int, was_crit: bool) -> void:
	value += new_value
	number_label.text = str(value)
	global_position = parent_node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(parent_node.sprite).y)
	position.x += starting_offset

	var src_type: String = source_type if not was_crit else "CritDamage"
	gradient_tex.texture = text_colors.get(src_type, GradientTexture1D.new())

	if is_healing:
		glow.modulate = Color(0, 0.859, 0.18, 0.9)
		number_label.text = "+" + number_label.text
	else:
		glow.modulate = Color(1.25, 0.2, 0.3, 1.0)

	modulate.a = 1.0
	skew = -deg_to_rad(15)
	number_outline.text = number_label.text

	if was_crit:
		scale = starting_scale * 1.15
	else:
		scale = starting_scale

	glow.custom_minimum_size.x = 20 + (10 * (number_label.text.length() - 1))
	gradient_tex.size.x = 278 * number_label.text.length()

	_tween_self()

## Tweens the animated properties of the popup then frees it.
func _tween_self() -> void:
	if tween: tween.kill()
	tween = create_tween()

	tween.tween_property(self, "scale", scale * 1.25, 0.14).set_trans(Tween.TRANS_SPRING)
	tween.parallel().tween_property(self, "skew", 0.0, 0.14)
	tween.parallel().tween_property(self, "position", position + Vector2(2, 2), 0.06)

	tween.tween_interval(0.14)

	tween.chain().tween_property(self, "global_position", global_position + Vector2(-2 if starting_offset < 0 else 4, -5), 0.25)
	tween.parallel().tween_property(self, "scale", scale * 0.5, 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.35, 0.25)
	tween.parallel().tween_property(self, "skew", deg_to_rad(5.0), 0.25)
	tween.chain().tween_callback(queue_free)
