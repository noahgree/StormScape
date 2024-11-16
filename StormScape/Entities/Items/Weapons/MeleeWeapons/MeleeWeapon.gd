extends Weapon
class_name MeleeWeapon

@export var sprite_visual_rotation: float = 45 ## How rotated the drawn sprite is by default when imported. Straight up would be 0º, angling top-right would be 45º, etc.
@export var ghost_scene: PackedScene = load("res://Entities/EntityCore/SpriteGhost.tscn")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.25 ## How long ghosts take to fade.

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this melee weapon.
@onready var hitbox_component: HitboxComponent = $AnimatedSprite2D/HitboxComponent ## The hitbox responsible for applying the melee hit.

var s_stats: MeleeWeaponResource ## Self stats, only exists to give us type hints for this specific kind of item resource.
var cooldown_timer: Timer = Timer.new()
var charge_cooldown_timer: Timer = Timer.new()
var is_swinging: bool = false
var is_holding: bool = false
const HOLDING_THRESHOLD: float = 0.1


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	s_stats = stats.duplicate()
	source_slot.item.stats = s_stats

	if hitbox_component:
		hitbox_component.effect_source = s_stats.effect_source
		hitbox_component.collision_mask = hitbox_component.effect_source.scanned_phys_layers

func _ready() -> void:
	super._ready()

	add_child(cooldown_timer)
	add_child(charge_cooldown_timer)
	cooldown_timer.one_shot = true
	charge_cooldown_timer.one_shot = true

	hitbox_component.source_entity = source_entity

func enter() -> void:
	if s_stats.cooldown_left > 0:
		cooldown_timer.start(s_stats.cooldown_left)
	if s_stats.charge_cooldown_left > 0:
		charge_cooldown_timer.start(s_stats.charge_use_cooldown)

func exit() -> void:
	source_entity.move_fsm.should_rotate = true

	s_stats.cooldown_left = cooldown_timer.time_left
	s_stats.charge_cooldown_left = charge_cooldown_timer.time_left

	s_stats.time_last_equipped = Time.get_ticks_msec() / 1000.0

## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	if is_swinging:
		return

	is_holding = false
	await get_tree().create_timer(HOLDING_THRESHOLD, false, false, false).timeout
	if not is_holding or not s_stats.can_do_charge_use:
		if pullout_delay_timer.is_stopped() and cooldown_timer.is_stopped():
			if not source_entity.hands.scale_is_lerping:
				_swing()

func hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not cooldown_timer.is_stopped() or not charge_cooldown_timer.is_stopped() or is_swinging:
		source_entity.hands.been_holding_time = 0
		return

	if hold_time >= HOLDING_THRESHOLD:
		is_holding = true
		if s_stats.auto_do_charge_use and s_stats.can_do_charge_use:
			_charge_swing(hold_time)

func release_hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not cooldown_timer.is_stopped() or not charge_cooldown_timer.is_stopped() or is_swinging:
		source_entity.hands.been_holding_time = 0
		return

	if hold_time >= HOLDING_THRESHOLD and not s_stats.auto_do_charge_use and s_stats.can_do_charge_use:
		_charge_swing(hold_time)

func _swing() -> void:
	if source_entity.stamina_component.use_stamina(s_stats.stamina_cost):
		cooldown_timer.start(s_stats.cooldown + s_stats.use_speed)
		is_swinging = true
		source_entity.move_fsm.should_rotate = false

		_apply_start_use_effect(false)

		var lib: AnimationLibrary = anim_player.get_animation_library("MeleeWeaponAnimLibrary")
		var anim: Animation = lib.get_animation("use")
		var main_sprite_track: int = anim.find_track("AnimatedSprite2D:rotation", Animation.TYPE_VALUE)
		anim.track_set_key_value(main_sprite_track, 1, deg_to_rad(s_stats.swing_angle))

		anim_player.speed_scale = 1.0 / s_stats.use_speed
		anim_player.play("MeleeWeaponAnimLibrary/use")
		if s_stats.usage_sound != "":
			AudioManager.play_sound(s_stats.usage_sound, AudioManager.SoundType.SFX_2D, source_entity.global_position)

func _charge_swing(hold_time: float) -> void:
	if not (hold_time >= s_stats.min_charge_time):
		return

	if s_stats.charge_effect_source == null:
		s_stats.charge_effect_source = s_stats.effect_source

	if source_entity.stamina_component.use_stamina(s_stats.charge_stamina_cost):
		cooldown_timer.start(s_stats.charge_use_cooldown + s_stats.charge_use_speed)
		is_swinging = true
		source_entity.move_fsm.should_rotate = false
		source_entity.hands.snap_y_scale()

		_apply_start_use_effect(true)

		var lib: AnimationLibrary = anim_player.get_animation_library("MeleeWeaponAnimLibrary")
		var anim: Animation = lib.get_animation("charge_use")
		var main_sprite_track: int = anim.find_track("AnimatedSprite2D:rotation", Animation.TYPE_VALUE)
		anim.track_set_key_value(main_sprite_track, 1, deg_to_rad(s_stats.charge_swing_angle))

		anim_player.speed_scale = 1.0 / s_stats.charge_use_speed
		anim_player.play("MeleeWeaponAnimLibrary/charge_use")
		if s_stats.charge_use_sound != "":
			AudioManager.play_sound(s_stats.charge_use_sound, AudioManager.SoundType.SFX_2D, source_entity.global_position)

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

## Applies a status effect to the source entity at the start of use.
func _apply_start_use_effect(was_charge_fire: bool = false) -> void:
	var effect: StatusEffect = s_stats.use_start_effect if not was_charge_fire else s_stats.chg_use_start_effect
	if effect != null:
		source_entity.effect_receiver.handle_status_effect(effect)

## Applies a status effect to the source entity after use.
func _apply_post_use_effect(was_charge_fire: bool = false) -> void:
	var effect: StatusEffect = s_stats.post_use_effect if not was_charge_fire else s_stats.post_chg_use_effect
	if effect != null:
		source_entity.effect_receiver.handle_status_effect(effect)

func _on_use_animation_ended(was_charge_use: bool = false) -> void:
	is_swinging = false
	source_entity.move_fsm.should_rotate = true

	_apply_post_use_effect(was_charge_use)
