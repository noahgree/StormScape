@tool
extends Weapon
class_name ProjectileWeapon
## Base class for all weapons that spawn any sort of projectile.

@export var proj_origin: Vector2 = Vector2.ZERO:
	set(new_origin):
		proj_origin = new_origin
		if proj_origin_node:
			proj_origin_node.position = proj_origin

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this projectile weapon.
@onready var proj_origin_node: Marker2D = $ProjectileOrigin ## The point at which projectiles should spawn from.

var s_stats: ProjWeaponResource ## Self stats, only exists to give us type hints for this specific kind of item resource.
var auto_fire_delay_timer: Timer = Timer.new()
var charge_fire_cooldown_timer: Timer = Timer.new()


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	s_stats = stats

func _ready() -> void:
	super._ready()
	add_child(auto_fire_delay_timer)
	add_child(charge_fire_cooldown_timer)
	auto_fire_delay_timer.one_shot = true
	charge_fire_cooldown_timer.one_shot = true

func enter() -> void:
	if s_stats.auto_fire_delay_left > 0:
		auto_fire_delay_timer.start(s_stats.auto_fire_delay_left)

func exit() -> void:
	source_entity.move_fsm.should_rotate = true
	if not auto_fire_delay_timer.is_stopped():
		s_stats.auto_fire_delay_left = auto_fire_delay_timer.time_left
	else:
		s_stats.auto_fire_delay_left = 0

## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	if s_stats.firing_mode == "Semi Auto":
		_fire()

func hold_activate(_hold_time: float) -> void:
	if s_stats.firing_mode == "Auto":
		_fire()

func release_hold_activate(hold_time: float) -> void:
	if s_stats.firing_mode == "Charge":
		_charge_fire(hold_time)

func _fire() -> void:
	if not auto_fire_delay_timer.is_stopped():
		return
	else:
		auto_fire_delay_timer.start(s_stats.auto_fire_delay)
		s_stats.effect_source.source_entity = source_entity

	_create_projectile(false)
	_do_firing_fx(false)
	_start_firing_anim(false)

func _charge_fire(hold_time: float) -> void:
	if (s_stats.min_charge_time > 0):
		if (hold_time >= s_stats.min_charge_time) and charge_fire_cooldown_timer.is_stopped():
			_create_projectile(true)
			_do_firing_fx(true)
			_start_firing_anim(true)

func _create_projectile(was_charge_fire: bool = false) -> void:
	var source: EffectSource = s_stats.effect_source if not was_charge_fire else s_stats.charge_effect_source
	var proj: Projectile = Projectile.spawn(s_stats, source, proj_origin_node.global_position, global_rotation)
	GlobalData.world_root.add_child(proj)

func _do_firing_fx(with_charge_mult: bool = false) -> void:
	var multiplier: float = s_stats.charge_cam_fx_mult if with_charge_mult else 1.0
	if s_stats.auto_fire_delay > s_stats.firing_cam_shake_dur:
		GlobalData.player_camera.start_shake(s_stats.firing_cam_shake_str * multiplier, s_stats.firing_cam_shake_dur * multiplier)
	if s_stats.auto_fire_delay > s_stats.firing_cam_freeze_dur:
		GlobalData.player_camera.start_freeze(s_stats.firing_cam_freeze_str * multiplier, s_stats.firing_cam_freeze_dur * multiplier)
	var sound: String = s_stats.firing_sound if not with_charge_mult else s_stats.charge_firing_sound
	if sound != "": AudioManager.play_sound(sound, AudioManager.SoundType.SFX_2D, global_position)

func _start_firing_anim(was_charge_fire: bool = false) -> void:
	if not was_charge_fire:
		anim_player.speed_scale = 1.0 / s_stats.auto_fire_delay
		anim_player.play("fire")
	else:
		if s_stats.has_charge_fire_anim:
			anim_player.speed_scale = 1.0
		anim_player.play("charge_fire")

func _on_animation_ended(was_charge_fire: bool = false) -> void:
	if was_charge_fire:
		if s_stats.charge_fire_cooldown > 0:
			charge_fire_cooldown_timer.start(s_stats.charge_fire_cooldown)
			await charge_fire_cooldown_timer.timeout
			source_entity.hands.been_holding_time = 0
