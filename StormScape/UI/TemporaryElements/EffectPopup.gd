extends Marker2D
class_name EffectPopup
## The popup that displays briefly after an effect source is applied. Shows things like the applied damage or healing values.

static var popup_scene: PackedScene = preload("res://UI/TemporaryElements/EffectPopup.tscn") ## The popup scene to be instantiated when a popup is created above something.

@export var text_colors: Dictionary[String, GradientTexture1D] ## The strings that have associated colors to change the text color to.

@onready var number_label: Label = $CenterContainer/NumberLabel ## The popup's numbers.
@onready var number_outline: Label = $CenterContainer/NumberOutline ## The outline of the popup's numbers.
@onready var glow: TextureRect = $CenterContainer/Glow ## The glow behind the popup's numbers.
@onready var gradient_tex: TextureRect = $CenterContainer/NumberLabel/GradientTex ## The texture overlay that changes the numbers' colors.
@onready var starting_scale: Vector2 = scale ## The scale of the popup when first created.

var value: int = 0 ## The current value of the popup.
var parent_node: Entity ## The parent of the popup node.
var tween: Tween ## The tween animating the motion and scale of the popup.
var was_healing_before: bool = false ## Whether or not we were healing the last time the popup was updated.

## Creates and adds an effect popup to the entity that requested it.
static func create_popup(src_type: String, was_healing: bool,
						was_crit: bool, popup_value: int, node: Entity) -> EffectPopup:
	var popup: EffectPopup = popup_scene.instantiate()

	popup.parent_node = node
	popup.global_position = node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(node.sprite).y)

	Globals.world_root.add_child(popup)
	popup.update_popup(popup_value, src_type, was_crit, was_healing)

	return popup

## Updates or sets up the popup displaying an effect's values above the entity's head.
func update_popup(new_value: int, src_type: String, is_crit: bool, is_healing: bool) -> void:
	if (was_healing_before and not is_healing) or (not was_healing_before and is_healing):
		value = new_value
	else:
		value += new_value
	was_healing_before = is_healing

	number_label.text = str(value)
	global_position = parent_node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(parent_node.sprite).y)

	gradient_tex.texture = text_colors.get(src_type if not is_crit else "crit_damage", GradientTexture1D.new())

	if is_healing:
		glow.modulate = Color(0, 0.859, 0.18, 0.9)
		number_label.text = "+" + number_label.text
	else:
		glow.modulate = Color(1.25, 0.2, 0.3, 1.0)
		number_label.text = number_label.text

	modulate.a = 1.0
	skew = -deg_to_rad(15)
	number_outline.text = number_label.text

	if is_crit:
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

	tween.chain().tween_property(self, "global_position", global_position + Vector2(0, -5), 0.25)
	tween.parallel().tween_property(self, "scale", scale * 0.5, 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.35, 0.25)
	tween.parallel().tween_property(self, "skew", deg_to_rad(5.0), 0.25)
	tween.chain().tween_callback(queue_free)
