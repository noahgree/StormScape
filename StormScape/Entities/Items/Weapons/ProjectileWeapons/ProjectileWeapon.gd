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
var firing_delay_timer: Timer = Timer.new()
var charge_fire_cooldown_timer: Timer = Timer.new()
var initial_shot_delay_timer: Timer = Timer.new()
var just_released: bool = false


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	s_stats = stats

func _ready() -> void:
	super._ready()

	add_child(firing_delay_timer)
	add_child(charge_fire_cooldown_timer)
	add_child(initial_shot_delay_timer)
	firing_delay_timer.one_shot = true
	charge_fire_cooldown_timer.one_shot = true
	initial_shot_delay_timer.one_shot = true

func enter() -> void:
	if s_stats.auto_fire_delay_left > 0:
		firing_delay_timer.start(s_stats.auto_fire_delay_left)

func exit() -> void:
	source_entity.move_fsm.should_rotate = true
	if not firing_delay_timer.is_stopped():
		s_stats.auto_fire_delay_left = firing_delay_timer.time_left
	else:
		s_stats.auto_fire_delay_left = 0
	just_released = false
	s_stats.current_warmth_level = 0

func _process(delta: float) -> void:
	if firing_delay_timer.is_stopped():
		if s_stats.current_bloom_level > 0:
			var bloom_decrease_amount: float = max(0.01 * delta, s_stats.bloom_decrease_rate.sample_baked(s_stats.current_bloom_level) * delta)
			s_stats.current_bloom_level = max(0, s_stats.current_bloom_level - bloom_decrease_amount)

		if s_stats.current_warmth_level > 0:
			var warmth_decrease_amount: float = max(0.01 * delta, s_stats.warmth_decrease_rate.sample_baked(s_stats.current_warmth_level) * delta)
			s_stats.current_warmth_level = max(0, s_stats.current_warmth_level - warmth_decrease_amount)

## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	if not pullout_delay_timer.is_stopped():
		return

	if s_stats.firing_mode == "Semi Auto":
		_fire()

func hold_activate(_hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped():
		source_entity.hands.been_holding_time = 0
		return

	if s_stats.firing_mode == "Auto":
		_fire()

func release_hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped():
		source_entity.hands.been_holding_time = 0
		return

	if s_stats.firing_mode == "Charge":
		_charge_fire(hold_time)

	just_released = true

func _fire() -> void:
	if not firing_delay_timer.is_stopped():
		return

	s_stats.effect_source.source_entity = source_entity

	if s_stats.initial_shot_delay > 0:
		if initial_shot_delay_timer.is_stopped():
			initial_shot_delay_timer.start(s_stats.initial_shot_delay)
			await initial_shot_delay_timer.timeout
		else:
			return

	if _get_warmth_firing_delay() > 0:
		firing_delay_timer.start(_get_warmth_firing_delay())
		await firing_delay_timer.timeout
		if just_released:
			just_released = false
			return

	_handle_warmth_increase()
	_apply_burst_logic(false)

func _charge_fire(hold_time: float) -> void:
	if s_stats.charge_effect_source == null:
		s_stats.charge_effect_source = s_stats.effect_source
	if s_stats.charge_projectile_data == null:
		s_stats.charge_projectile_data = s_stats.projectile_data
	if s_stats.charge_projectile == null:
		s_stats.charge_projectile = s_stats.projectile
	s_stats.charge_effect_source.source_entity = source_entity

	if (s_stats.min_charge_time > 0):
		if (hold_time >= s_stats.min_charge_time) and charge_fire_cooldown_timer.is_stopped():
			_apply_burst_logic(true)

func _apply_burst_logic(was_charge_fire: bool = false) -> void:
	if s_stats.projectiles_per_fire > 1 and not s_stats.add_bloom_per_burst_shot: _handle_bloom_increase(was_charge_fire)
	var shots: int = s_stats.projectiles_per_fire

	var delay: float = _get_warmth_firing_delay() if _get_warmth_firing_delay() > 0 else s_stats.auto_fire_delay
	var delay_adjusted_for_burst: float = delay + (s_stats.burst_bullet_delay * (shots - 1))
	firing_delay_timer.start(delay_adjusted_for_burst)

	for i in range(shots):
		if s_stats.add_bloom_per_burst_shot or (s_stats.projectiles_per_fire == 1):
			_handle_bloom_increase(false)

		_apply_barrage_logic(was_charge_fire)
		if i != shots - 1:
			await get_tree().create_timer(s_stats.burst_bullet_delay, false, true, false).timeout

func _apply_barrage_logic(was_charge_fire: bool = false) -> void:
	var source: EffectSource = s_stats.effect_source if not was_charge_fire else s_stats.charge_effect_source
	var proj_scene: PackedScene = s_stats.projectile if not was_charge_fire else s_stats.charge_projectile
	var proj_stats: ProjectileResource = s_stats.projectile_data if not was_charge_fire else s_stats.charge_projectile_data

	var anuglar_spread_radians: float = deg_to_rad(s_stats.angluar_spread)
	var close_to_360_adjustment: int = 0 if s_stats.angluar_spread > 310 else 1
	var spread_segment_width = anuglar_spread_radians / (s_stats.barrage_count - close_to_360_adjustment)
	var start_rotation = global_rotation - (anuglar_spread_radians / 2.0)

	for i in range(s_stats.barrage_count):
		var proj: Projectile = Projectile.spawn(proj_scene, proj_stats, source, proj_origin_node.global_position, global_rotation)
		var rotation_adjustment: float = start_rotation + (i * spread_segment_width)
		proj.rotation = rotation_adjustment if s_stats.barrage_count > 1 else proj.rotation

		_spawn_projectile(proj, was_charge_fire)

func _spawn_projectile(proj, was_charge_fire: bool = false) -> void:
	proj.rotation += deg_to_rad(_get_bloom())
	GlobalData.world_root.add_child(proj)

	_do_firing_fx(was_charge_fire)
	_start_firing_anim(was_charge_fire)

func _handle_warmth_increase() -> void:
	var increase_amount: float = max(0.01, s_stats.warmth_increase_rate.sample_baked(s_stats.current_warmth_level))
	s_stats.current_warmth_level = min(1, s_stats.current_warmth_level + increase_amount)

func _get_warmth_firing_delay() -> float:
	if s_stats.fully_cool_delay_time > 0 and s_stats.firing_mode == "Auto":
		var delay: float = s_stats.warmth_delay_curve.sample_baked(s_stats.current_warmth_level)
		return max(0.02, delay * s_stats.fully_cool_delay_time)
	else:
		return 0

func _handle_bloom_increase(was_charge_fire: bool = false) -> void:
	var increase_amount: float = max(0.01, s_stats.bloom_increase_rate.sample_baked(s_stats.current_bloom_level))
	var charge_shot_mult: float = 1.0 if not was_charge_fire else s_stats.charge_bloom_mult
	s_stats.current_bloom_level = min(1, s_stats.current_bloom_level + (increase_amount * charge_shot_mult))

func _get_bloom() -> float:
	if s_stats.max_bloom > 0:
		var deviation: float = s_stats.bloom_curve.sample_baked(s_stats.current_bloom_level)
		var random_direction: int = 1 if randf() < 0.5 else -1
		return deviation * s_stats.max_bloom * random_direction * randf()
	else:
		return 0

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
		if s_stats.initial_shot_delay > 0 and anim_player.has_animation("delay_fire"):
			anim_player.speed_scale = 1.0
			anim_player.play("delay_fire")
		else:
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
