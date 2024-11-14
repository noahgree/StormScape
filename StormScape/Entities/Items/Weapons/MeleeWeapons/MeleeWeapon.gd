extends Weapon
class_name MeleeWeapon

@export var sprite_visual_rotation: float = 45 ## How rotated the drawn sprite is by default when imported. Straight up would be 0º, angling top-right would be 45º, etc.
@export var ghost_scene: PackedScene = load("res://Entities/EntityCore/SpriteGhost.tscn")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.25 ## How long ghosts take to fade.

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this melee weapon.
@onready var hitbox_component: HitboxComponent = $AnimatedSprite2D/HitboxComponent ## The hitbox responsible for applying the melee hit.

var s_stats: MeleeWeaponResource ## Self stats, only exists to give us type hints for this specific kind of item resource.
var cooldown_timer: Timer = Timer.new()


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	s_stats = stats
	if hitbox_component:
		hitbox_component.effect_source = s_stats.effect_source
		hitbox_component.collision_mask = hitbox_component.effect_source.scanned_phys_layers

func _ready() -> void:
	super._ready()
	add_child(cooldown_timer)
	cooldown_timer.one_shot = true

func enter() -> void:
	if s_stats.cooldown_left > 0:
		cooldown_timer.start(s_stats.cooldown_left)

func exit() -> void:
	source_entity.move_fsm.should_rotate = true
	if not cooldown_timer.is_stopped():
		s_stats.cooldown_left = cooldown_timer.time_left
	else:
		s_stats.cooldown_left = 0

## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	pass

func hold_activate(_hold_time: float) -> void:
	_swing()

func release_hold_activate(_hold_time: float) -> void:
	pass

func _swing() -> void:
	if not cooldown_timer.is_stopped():
		return

	s_stats.effect_source.source_entity = source_entity

	source_entity.move_fsm.should_rotate = false

	var anim: Animation = anim_player.get_animation("use")
	var main_sprite_track: int = anim.find_track("AnimatedSprite2D:rotation", Animation.TYPE_VALUE)
	anim.track_set_key_value(main_sprite_track, 1, deg_to_rad(s_stats.swing_angle))

	anim_player.speed_scale = 1.0 / s_stats.use_speed
	anim_player.play("use")

func _spawn_ghost() -> void:
	var current_anim: String = sprite.animation
	var current_frame: int = sprite.frame
	var sprite_texture: Texture2D = sprite.sprite_frames.get_frame_texture(current_anim, current_frame)

	var adjusted_transform: Transform2D = sprite.transform
	var rotated_offset = sprite.offset.rotated(sprite.rotation)
	adjusted_transform.origin += rotated_offset

	var ghost_instance: SpriteGhost = SpriteGhost.create(ghost_scene, adjusted_transform, sprite.scale, sprite_texture, ghost_fade_time)
	ghost_instance.flip_h = sprite.flip_h
	ghost_instance.make_white()
	add_child(ghost_instance)

func _on_animation_ended() -> void:
	source_entity.move_fsm.should_rotate = true
	cooldown_timer.start(s_stats.cooldown)
