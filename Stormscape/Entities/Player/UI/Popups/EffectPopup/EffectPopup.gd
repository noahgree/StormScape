extends Marker2D
class_name EffectPopup
## The popup that displays briefly after an effect source is applied. Shows things like the applied damage or healing values.

enum POPUP_CATEGORY { HEALTH, SHIELD } ## The two kinds of popups that this node hosts.

enum POPUP_TYPE { ## The kinds of ways that health and shield values can color and style the popups.
	SHIELD_DAMAGE,
	HEALTH_DAMAGE,
	SHIELD_HEALING,
	HEALTH_HEALING,
	CRIT_DAMAGE,
	BURNING,
	FROSTBITE,
	LIFE_STEAL,
	POISON,
	REGEN,
	STORM_SYNDROME,
	AUTO ## For basic changes that get determined by the sign of the amount.
}

static var popup_scene: PackedScene = preload("uid://28ry06t64e8p") ## The popup scene to be instantiated when a popup is created above something.

@export var txt_color_dict: Dictionary[EffectPopup.POPUP_TYPE, GradientTexture1D] ## The change types that have associated colors to change the text color to.

@onready var number_label: Label = $CenterContainer/NumberLabel ## The popup's numbers.
@onready var number_outline: Label = $CenterContainer/NumberOutline ## The outline of the popup's numbers.
@onready var glow: TextureRect = $CenterContainer/Glow ## The glow behind the popup's numbers.
@onready var gradient_tex: TextureRect = $CenterContainer/NumberLabel/GradientTex ## The texture overlay that changes the numbers' colors.
@onready var starting_scale: Vector2 = scale ## The scale of the popup when first created.

const ANIM_IN_TIME: float = 0.15
const ANIM_OUT_TIME: float = 0.5

var value: int = 0 ## The current value of the popup.
var multishot_id: int = -1
var parent_node: Entity ## The parent of the popup node.
var tween: Tween ## The tween animating the motion and scale of the popup.

## Creates and adds an effect popup to the entity that requested it.
static func create_popup(popup_type: POPUP_TYPE, popup_value: int, node: Entity, m_id: int) -> EffectPopup:
	var popup: EffectPopup = popup_scene.instantiate()

	popup.parent_node = node
	popup.global_position = node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(node.sprite).y)
	popup.multishot_id = m_id

	Globals.world_root.add_child(popup)
	popup.update_popup(popup_type, popup_value)

	return popup

## Updates or sets up the popup displaying an effect's values above the entity's head.
func update_popup(popup_type: POPUP_TYPE, new_value: int) -> void:
	value += new_value

	number_label.text = str(abs(value))
	global_position = parent_node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(parent_node.sprite).y)

	gradient_tex.texture = txt_color_dict.get(popup_type, GradientTexture1D.new())

	if popup_type in HPComponent.HEAL_CHANGE_TYPES:
		glow.modulate = Color(0, 0.859, 0.18, 0.9)
		number_label.text = "+" + number_label.text
	else:
		glow.modulate = Color(1.25, 0.2, 0.3, 1.0)
		number_label.text = number_label.text

	modulate.a = 1.0
	skew = -deg_to_rad(15)
	number_outline.text = number_label.text

	if popup_type == POPUP_TYPE.CRIT_DAMAGE:
		scale = starting_scale * 1.2
	else:
		scale = starting_scale

	glow.custom_minimum_size.x = 20 + (10 * (number_label.text.length() - 1))
	gradient_tex.size.x = 278 * number_label.text.length()

	_tween_self()

## Tweens the animated properties of the popup then frees it.
func _tween_self() -> void:
	if tween: tween.kill()
	tween = create_tween()

	tween.tween_property(self, "scale", scale * 1.25, ANIM_IN_TIME).set_trans(Tween.TRANS_SPRING)
	tween.parallel().tween_property(self, "skew", 0.0, ANIM_IN_TIME)
	tween.parallel().tween_property(self, "position", position + Vector2(randi_range(-2, 2), randi_range(2, 4)), 0.06)

	tween.chain().tween_property(self, "global_position", global_position + Vector2(randi_range(-5, 5), -9), ANIM_OUT_TIME)
	tween.parallel().tween_property(self, "scale", scale * 0.5, ANIM_OUT_TIME)
	tween.parallel().tween_property(self, "modulate:a", 0.35, ANIM_OUT_TIME)
	tween.parallel().tween_property(self, "skew", deg_to_rad(5.0), ANIM_OUT_TIME)
	tween.chain().tween_callback(queue_free)
