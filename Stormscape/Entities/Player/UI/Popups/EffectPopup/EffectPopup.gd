extends Node2D
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

@onready var number_label: Label = %NumberLabel ## The popup's numbers.
@onready var number_outline: Label = %NumberOutline ## The outline of the popup's numbers.
@onready var glow: TextureRect = %Glow ## The glow behind the popup's numbers.
@onready var gradient_tex: TextureRect = %GradientTex ## The texture overlay that changes the numbers' colors.
@onready var starting_scale: Vector2 = scale ## The scale of the popup when first created.

const ANIM_IN_TIME: float = 0.18
const ANIM_OUT_TIME: float = 1.0

var value: int = 0 ## The current value of the popup.
var multishot_id: int = -1 ## The id grouping together multishots.
var source_esi_uid: int = -1 ## The uid represting which ESI produced the values that caused this popup.
var parent_node: Entity ## The parent of the popup node.
var tween: Tween ## The tween animating the motion and scale of the popup.
var anim_time_mult: float = 1.0 ## Multiplies the anim in and out times by this.

## Creates and adds an effect popup to the entity that requested it.
static func create_popup(popup_type: POPUP_TYPE, popup_value: int, node: Entity, esi: ESI,
							timimg_mult: float) -> EffectPopup:
	var popup: EffectPopup = popup_scene.instantiate()
	Globals.world_root.add_child(popup)
	popup.parent_node = node

	popup.set_as_new(popup_type, popup_value, esi, timimg_mult)

	return popup

func set_as_new(popup_type: POPUP_TYPE, popup_value: int, esi: ESI, timing_mult: float) -> void:
	global_position = parent_node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(parent_node.sprite).y)
	multishot_id = esi.multishot_id
	source_esi_uid = esi.uid

	value = 0
	update_popup(popup_type, popup_value, timing_mult)

## Updates or sets up the popup displaying an effect's values above the entity's head.
func update_popup(popup_type: POPUP_TYPE, new_value: int, timimg_mult: float) -> void:
	value += new_value

	number_label.text = str(abs(value))
	global_position = parent_node.global_position - Vector2(0, SpriteHelpers.SpriteDetails.get_frame_rect(parent_node.sprite).y)

	gradient_tex.texture = txt_color_dict.get(popup_type, GradientTexture1D.new())

	if popup_type in HPComponent.HEAL_CHANGE_TYPES:
		glow.modulate = Color(0, 0.859, 0.18, 0.5)
		number_label.text = "+" + number_label.text
	else:
		glow.modulate = Color(1.25, 0.2, 0.3, 0.5)
		number_label.text = number_label.text

	modulate.a = 1.0
	skew = -deg_to_rad(15)
	number_outline.text = number_label.text

	if popup_type == POPUP_TYPE.CRIT_DAMAGE:
		scale = starting_scale * 1.2
	else:
		scale = starting_scale

	anim_time_mult = timimg_mult
	_tween_self()

## Tweens the animated properties of the popup then frees it.
func _tween_self() -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT)

	var anim_in_dur: float = ANIM_IN_TIME
	var anim_out_dur: float = ANIM_OUT_TIME * anim_time_mult

	tween.tween_property(self, "scale", scale * 1.25, anim_in_dur).set_trans(Tween.TRANS_SPRING)
	tween.parallel().tween_property(self, "skew", 0.0, anim_in_dur)
	tween.parallel().tween_property(self, "position", position + Vector2(randi_range(-2, 2), randi_range(2, 4)), anim_in_dur)

	tween.chain().tween_interval(0.25 * anim_time_mult)

	tween.chain().tween_property(self, "global_position", global_position + Vector2(randi_range(-5, 5), -10), anim_out_dur)
	#tween.parallel().tween_property(self, "rotation_degrees", 5.0, anim_out_dur)
	tween.parallel().tween_property(self, "scale", scale * 0.5, anim_out_dur)
	tween.parallel().tween_property(self, "modulate:a", 0.35, anim_out_dur)
	tween.parallel().tween_property(self, "skew", deg_to_rad(5.0), anim_out_dur)
	tween.chain().tween_callback(queue_free)
