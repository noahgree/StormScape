extends AnimatedSprite2D
class_name WeaponFiringVFX
## The VFX that spawn and play each time a weapon is fired.
##
## Note that any particles or specifically-timed events in this scene need be triggered via the animation player.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var display_time: float = 0.1
@export_range(0, 200, 0.1, "or_greater", "suffix:%") var glow_strength: float = 15.0
@export var glow_color: Color = Color.WHITE

@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	hide()
	self_modulate = glow_color * (1.0 + (glow_strength / 100.0))
	anim_player.speed_scale = 1.0 / display_time
	anim_player.animation_finished.connect(func(_anim_name: StringName) -> void: hide())

func start() -> void:
	show()
	anim_player.stop()
	if sprite_frames:
		var random_anim_index: int = randi_range(1, sprite_frames.get_animation_names().size())
		anim_player.get_animation("default").track_set_key_value(0, 0, str(random_anim_index))
	anim_player.play("default")
