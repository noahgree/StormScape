@tool
extends Weapon
class_name ProjectileWeapon
## Base class for all weapons that spawn any sort of projectile.

@export var proj_origin: Vector2 = Vector2.ZERO: ## Where the projectile spawns from in local space of the weapon scene.
	set(new_origin):
		proj_origin = new_origin
		if proj_origin_node:
			proj_origin_node.position = proj_origin

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this projectile weapon.
@onready var proj_origin_node: Marker2D = $ProjectileOrigin ## The point at which projectiles should spawn from.

var s_stats: ProjWeaponResource ## Self stats, only exists to give us type hints for this specific kind of item resource.
var firing_delay_timer: Timer = Timer.new() ## The timer tracking time between regular firing shots.
var charge_fire_cooldown_timer: Timer = Timer.new() ## The timer tracking how long after charge shots we are on charge cooldown.
var initial_shot_delay_timer: Timer = Timer.new() ## The timer tracking how long after we press fire before the proj spawns.
var mag_reload_timer: Timer = Timer.new() ## The timer tracking the delay between full mag reload start and end.
var single_reload_timer: Timer = Timer.new() ## The timer tracking the delay between single bullet reloads.
var hold_just_released: bool = false ## Whether the mouse hold was just released.
var is_reloading_single_and_has_since_released: bool = true ## Whether we've begun reloading one bullet at a time and have relased the mouse since starting.
var is_charging: bool = false ## Whether the weapon is currently charging up for a charge shot.
var hitscan_delay: float = 0


#region EquippableItem Core
func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	s_stats = stats.duplicate()
	source_slot.item.stats = s_stats

func _ready() -> void:
	if not Engine.is_editor_hint():
		super._ready()

		add_child(firing_delay_timer)
		add_child(charge_fire_cooldown_timer)
		add_child(initial_shot_delay_timer)
		add_child(mag_reload_timer)
		add_child(single_reload_timer)
		firing_delay_timer.one_shot = true
		charge_fire_cooldown_timer.one_shot = true
		initial_shot_delay_timer.one_shot = true
		mag_reload_timer.one_shot = true
		single_reload_timer.one_shot = true
		single_reload_timer.timeout.connect(_on_single_reload_timer_timeout)

func enter() -> void:
	_handle_reequipping_stats()

	if (s_stats.ammo_in_mag == -1) and (s_stats.ammo_type != GlobalData.ProjAmmoType.STAMINA):
		s_stats.ammo_in_mag = s_stats.mag_size
	else:
		_get_has_needed_ammo_and_reload_if_not()

	if s_stats.auto_fire_delay_left > 0:
		firing_delay_timer.start(s_stats.auto_fire_delay_left)

func exit() -> void:
	source_entity.move_fsm.should_rotate = true
	source_entity.hands.equipped_item_should_follow_mouse = true
	s_stats.current_warmth_level = 0

	if s_stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal(s_stats.charging_stat_effect.effect_name)

	if not firing_delay_timer.is_stopped():
		s_stats.auto_fire_delay_left = firing_delay_timer.time_left
	else:
		s_stats.auto_fire_delay_left = 0

	s_stats.time_last_equipped = Time.get_ticks_msec() / 1000.0

## Checks how long since we last had this equipped and changes bloom accordingly.
func _handle_reequipping_stats() -> void:
	var time_since_last_equipped: float = (Time.get_ticks_msec() / 1000.0) - s_stats.time_last_equipped
	var forgiveness_factor: float = min(1.0, time_since_last_equipped / 5.0)
	s_stats.current_bloom_level = s_stats.current_bloom_level * (1 - forgiveness_factor)

## Every frame we decrease the warmth and the bloom levels based on their decrease curves.
func _process(delta: float) -> void:
	if firing_delay_timer.is_stopped() and not Engine.is_editor_hint():
		if s_stats.current_bloom_level > 0:
			var bloom_decrease_amount: float = max(0.01 * delta, s_stats.bloom_decrease_rate.sample_baked(s_stats.current_bloom_level) * delta)
			s_stats.current_bloom_level = max(0, s_stats.current_bloom_level - bloom_decrease_amount)

		if s_stats.current_warmth_level > 0:
			var warmth_decrease_amount: float = max(0.01 * delta, s_stats.warmth_decrease_rate.sample_baked(s_stats.current_warmth_level) * delta)
			s_stats.current_warmth_level = max(0, s_stats.current_warmth_level - warmth_decrease_amount)
#endregion

#region Called From HandsComponent
## Called from the hands component when the mouse is clicked.
func activate() -> void:
	if not pullout_delay_timer.is_stopped() or not mag_reload_timer.is_stopped():
		return

	is_reloading_single_and_has_since_released = true

	if s_stats.firing_mode == "Semi Auto":
		_fire()

## Called from the hands component when the mouse is held down. Includes how long it has been held down so far.
func hold_activate(_hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not mag_reload_timer.is_stopped():
		source_entity.hands.been_holding_time = 0
		return

	if s_stats.firing_mode == "Auto":
		_fire()
	elif s_stats.firing_mode == "Charge":
		if not is_charging and s_stats.charging_stat_effect != null:
			var effect: StatusEffect = s_stats.charging_stat_effect.duplicate()
			effect.mod_time = 100000000
			source_entity.effect_receiver.handle_status_effect(effect)
			is_charging = true

## Called from the hands component when we release the mouse. Includes how long we had it held down.
func release_hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not mag_reload_timer.is_stopped():
		source_entity.hands.been_holding_time = 0
		return

	is_reloading_single_and_has_since_released = true

	if s_stats.firing_mode == "Charge":
		if s_stats.charging_stat_effect != null:
			source_entity.effects.request_effect_removal(s_stats.charging_stat_effect.effect_name)
		_charge_fire(hold_time)
		is_charging = false

	hold_just_released = true

## Called from the hands component to try and start a reload.
func reload() -> void:
	if s_stats.ammo_type != GlobalData.ProjAmmoType.STAMINA:
		if pullout_delay_timer.is_stopped() and mag_reload_timer.is_stopped() and single_reload_timer.is_stopped():
			_attempt_reload()
#endregion

#region Firing Activations
## Check if we can do a normal firing, and if we can, start it.
func _fire() -> void:
	if not firing_delay_timer.is_stopped():
		return
	if not is_reloading_single_and_has_since_released:
		return
	if not _get_has_needed_ammo_and_reload_if_not(false):
		return

	single_reload_timer.stop()

	if s_stats.initial_shot_delay > 0:
		if initial_shot_delay_timer.is_stopped():
			initial_shot_delay_timer.start(s_stats.initial_shot_delay)
			await initial_shot_delay_timer.timeout
		else:
			return

	if _get_warmth_firing_delay() > 0:
		firing_delay_timer.start(_get_warmth_firing_delay())
		await firing_delay_timer.timeout
		if hold_just_released:
			hold_just_released = false
			return

	_set_up_hitscan(false)
	_handle_warmth_increase()
	_apply_burst_logic(false)
	_apply_post_firing_effect(false)

## Check if we can do a charge firing, and if we can, start it.
func _charge_fire(hold_time: float) -> void:
	if not _get_has_needed_ammo_and_reload_if_not(true):
		source_entity.hands.been_holding_time = 0
		return

	if s_stats.charge_effect_source == null:
		s_stats.charge_effect_source = s_stats.effect_source
	if s_stats.charge_projectile_data == null:
		s_stats.charge_projectile_data = s_stats.projectile_data
	if s_stats.charge_projectile == null:
		s_stats.charge_projectile = s_stats.projectile

	if (hold_time >= s_stats.min_charge_time) and (hold_time > 0) and charge_fire_cooldown_timer.is_stopped():
		_apply_burst_logic(true)
		_apply_post_firing_effect(true)

func _set_up_hitscan(_was_charge_fire: bool = false) -> void:
	if not s_stats.use_hitscan:
		hitscan_delay = 0
	else:
		hitscan_delay = s_stats.hitscan_duration
#endregion

#region Projectile Spawning
## Applies bursting logic to potentially shoot more than one projectile at a short, set interval.
func _apply_burst_logic(was_charge_fire: bool = false) -> void:
	if s_stats.projectiles_per_fire > 1 and not s_stats.add_bloom_per_burst_shot: _handle_bloom_increase(was_charge_fire)
	var shots: int = s_stats.projectiles_per_fire

	var delay: float = _get_warmth_firing_delay() if _get_warmth_firing_delay() > 0 else s_stats.auto_fire_delay + hitscan_delay
	var delay_adjusted_for_burst: float = delay + (s_stats.burst_bullet_delay * (shots - 1))
	firing_delay_timer.start(max(0.03, delay_adjusted_for_burst))

	if not was_charge_fire:
		if s_stats.use_ammo_per_burst_proj:
			for i in range(shots):
				_consume_ammo(1)
		else:
			_consume_ammo(1)
	else:
		_consume_ammo(s_stats.ammo_use_per_charge)

	for i in range(shots):
		if s_stats.add_bloom_per_burst_shot or (s_stats.projectiles_per_fire == 1):
			_handle_bloom_increase(false)

		_apply_barrage_logic(was_charge_fire)

		if i != (shots - 1):
			await get_tree().create_timer(s_stats.burst_bullet_delay, false, true, false).timeout

## Applies barrage logic to potentially spawn multiple projectiles at a specific angle apart.
func _apply_barrage_logic(was_charge_fire: bool = false) -> void:
	var effect_src: EffectSource = s_stats.effect_source if not was_charge_fire else s_stats.charge_effect_source
	var proj_scene: PackedScene = s_stats.projectile if not was_charge_fire else s_stats.charge_projectile
	var proj_stats: ProjectileResource = s_stats.projectile_data if not was_charge_fire else s_stats.charge_projectile_data

	var anuglar_spread_radians: float = deg_to_rad(s_stats.angluar_spread)
	var close_to_360_adjustment: int = 0 if s_stats.angluar_spread > 310 else 1
	var spread_segment_width = anuglar_spread_radians / (s_stats.barrage_count - close_to_360_adjustment)
	var start_rotation = global_rotation - (anuglar_spread_radians / 2.0)

	for i in range(s_stats.barrage_count):
		var rotation_adjustment: float = start_rotation + (i * spread_segment_width)

		if not s_stats.use_hitscan:
			var proj: Projectile = Projectile.create(proj_scene, proj_stats, effect_src, source_entity, proj_origin_node.global_position, global_rotation)
			proj.rotation = rotation_adjustment if s_stats.barrage_count > 1 else proj.rotation
			proj.starting_proj_height = -(source_entity.hands.position.y + proj_origin.y) / 2
			_spawn_projectile(proj, was_charge_fire)
		else:
			var hitscan: Hitscan = Hitscan.create(s_stats.hitscan, effect_src, self, source_entity, proj_origin_node.global_position, global_rotation)
			hitscan.rotation = rotation_adjustment if s_stats.barrage_count > 1 else hitscan.rotation
			_spawn_hitscan(hitscan, was_charge_fire)

## Spawns the projectile that has been passed to it. Reloads if we don't have enough for the next activation.
func _spawn_projectile(proj: Projectile, was_charge_fire: bool = false) -> void:
	proj.rotation += deg_to_rad(_get_bloom())
	GlobalData.world_root.add_child(proj)

	_do_firing_fx(was_charge_fire)
	_start_firing_anim(was_charge_fire)

	await firing_delay_timer.timeout
	_get_has_needed_ammo_and_reload_if_not(was_charge_fire)

## Spawns the hitscan that has been passed to it. Reloads if we don't have enough for the next activation.
func _spawn_hitscan(hitscan: Hitscan, was_charge_fire: bool = false) -> void:
	hitscan.rotation += deg_to_rad(_get_bloom())
	GlobalData.world_root.add_child(hitscan)

	_do_firing_fx(was_charge_fire)
	_start_firing_anim(was_charge_fire)

	await firing_delay_timer.timeout
	_get_has_needed_ammo_and_reload_if_not(was_charge_fire)

## Takes away either the passed in amount from the appropriate ammo reserve.
func _consume_ammo(amount: int) -> void:
	if s_stats.ammo_type == GlobalData.ProjAmmoType.STAMINA:
		(source_entity as DynamicEntity).stamina_component.use_stamina(amount * s_stats.stamina_use_per_proj)
	else:
		s_stats.ammo_in_mag -= amount
#endregion

#region Warmth & Bloom
## Increases current warmth level via sampling the increase curve using the current warmth.
func _handle_warmth_increase() -> void:
	var increase_amount: float = max(0.01, s_stats.warmth_increase_rate.sample_baked(s_stats.current_warmth_level))
	s_stats.current_warmth_level = min(1, s_stats.current_warmth_level + increase_amount)

## Grabs a point from the warmth curve based on current warmth level.
func _get_warmth_firing_delay() -> float:
	if s_stats.fully_cool_delay_time > 0 and s_stats.firing_mode == "Auto":
		var delay: float = s_stats.warmth_delay_curve.sample_baked(s_stats.current_warmth_level)
		return max(0.02, delay * s_stats.fully_cool_delay_time) + hitscan_delay
	else:
		return 0

## Increases current bloom level via sampling the increase curve using the current bloom.
func _handle_bloom_increase(was_charge_fire: bool = false) -> void:
	var increase_amount: float = max(0.01, s_stats.bloom_increase_rate.sample_baked(s_stats.current_bloom_level))
	var charge_shot_mult: float = 1.0 if not was_charge_fire else s_stats.charge_bloom_mult
	s_stats.current_bloom_level = min(1, s_stats.current_bloom_level + (increase_amount * charge_shot_mult))

## Grabs a point from the bloom curve based on current bloom level.
func _get_bloom() -> float:
	if s_stats.max_bloom > 0:
		var deviation: float = s_stats.bloom_curve.sample_baked(s_stats.current_bloom_level)
		var random_direction: int = 1 if randf() < 0.5 else -1
		return deviation * s_stats.max_bloom * random_direction * randf()
	else:
		return 0
#endregion

#region FX & Animations
## Start the sounds and vfx that should play when firing.
func _do_firing_fx(with_charge_mult: bool = false) -> void:
	var multiplier: float = s_stats.charge_cam_fx_mult if with_charge_mult else 1.0
	if s_stats.firing_cam_shake_dur > 0:
		var dur: float = min(s_stats.firing_cam_shake_dur, max(0, s_stats.auto_fire_delay + hitscan_delay - 0.01))
		GlobalData.player_camera.start_shake(s_stats.firing_cam_shake_str * multiplier, dur * multiplier)
	if s_stats.firing_cam_freeze_dur > 0:
		var dur: float = min(s_stats.firing_cam_freeze_dur, max(0, s_stats.auto_fire_delay + hitscan_delay - 0.01))
		GlobalData.player_camera.start_freeze(s_stats.firing_cam_freeze_mult * multiplier, dur * multiplier)
	var sound: String = s_stats.firing_sound if not with_charge_mult else s_stats.charge_firing_sound
	if sound != "": AudioManager.play_sound(sound, AudioManager.SoundType.SFX_2D, global_position)

## Start the firing animation based on what kind of firing we are doing.
func _start_firing_anim(was_charge_fire: bool = false) -> void:
	if not was_charge_fire:
		if s_stats.initial_shot_delay > 0 and anim_player.has_animation("delay_fire"):
			anim_player.speed_scale = 1.0
			anim_player.play("delay_fire")
		else:
			anim_player.speed_scale = 1.0 / (s_stats.auto_fire_delay + hitscan_delay)
			anim_player.play("fire")
	else:
		if s_stats.has_charge_fire_anim:
			anim_player.speed_scale = 1.0
		anim_player.play("charge_fire")

## When the firing animation ends, start the post firing cooldown if it was a charge shot.
func _on_firing_animation_ended(was_charge_fire: bool = false) -> void:
	if was_charge_fire:
		if s_stats.charge_fire_cooldown > 0:
			charge_fire_cooldown_timer.start(s_stats.charge_fire_cooldown)
			await charge_fire_cooldown_timer.timeout
			source_entity.hands.been_holding_time = 0

## Applies a status effect to the source entity after firing.
func _apply_post_firing_effect(was_charge_fire: bool = false) -> void:
	var effect: StatusEffect = s_stats.post_firing_effect if not was_charge_fire else s_stats.post_chg_shot_effect
	if effect != null:
		source_entity.effect_receiver.handle_status_effect(effect)
#endregion

#region Reloading
## Checks if we have enough ammo to execute a single firing. Calls for a reload if we don't.
func _get_has_needed_ammo_and_reload_if_not(was_charge_fire: bool = false) -> bool:
	if s_stats.ammo_type == GlobalData.ProjAmmoType.STAMINA and (source_entity is not DynamicEntity):
		push_error(source_entity.name + " is using a weapon with ammo type \"Stamina\" but is not a dynamic entity.")
		return false

	var result: bool = false
	var ammo_needed: int = 0

	if was_charge_fire:
		ammo_needed = s_stats.ammo_use_per_charge
	else:
		if s_stats.use_ammo_per_burst_proj:
			ammo_needed += s_stats.projectiles_per_fire
		else:
			ammo_needed = 1

	if s_stats.ammo_type == GlobalData.ProjAmmoType.STAMINA:
		var stamina_uses_left: int = int(floor(source_entity.stamina_component.stamina / (ammo_needed * s_stats.stamina_use_per_proj)))
		if stamina_uses_left > 0:
			result = true
	else:
		if s_stats.ammo_in_mag >= ammo_needed:
			result = true
		if result == false:
			_attempt_reload()
			if s_stats.empty_mag_sound != "":
				AudioManager.play_sound(s_stats.empty_mag_sound, AudioManager.SoundType.SFX_GLOBAL)

	return result

## Based on the reload method, starts the timer(s) needed to track how long the reload will take.
func _attempt_reload() -> void:
	var ammo_needed: int = s_stats.mag_size - s_stats.ammo_in_mag
	if ammo_needed > 0:
		source_entity.hands.been_holding_time = 0

	if s_stats.reload_type == "Single":
		is_reloading_single_and_has_since_released = false
		s_stats.ammo_in_mag += _get_more_reload_ammo(1)
		single_reload_timer.set_meta("reloads_left", ammo_needed - 1)
		single_reload_timer.start(s_stats.single_proj_reload_time)
	else:
		mag_reload_timer.start(s_stats.mag_reload_time)
		await mag_reload_timer.timeout
		s_stats.ammo_in_mag += _get_more_reload_ammo(ammo_needed)

## Searches through the source entity's inventory for more ammo to fill the magazine.
func _get_more_reload_ammo(max_amount_needed: int) -> int:
	var ammount_collected: int = 0
	var inv_node = source_entity.inv

	for i in range(inv_node.inv_size):
		var item = inv_node.inv[i]
		if item != null and (item.stats is ProjAmmoResource) and (item.stats.ammo_type == stats.ammo_type):
			var amount_in_slot: int = item.quantity
			var amount_still_needed: int = max_amount_needed - ammount_collected
			var amount_to_take_from_slot: int = min(amount_still_needed, amount_in_slot)
			inv_node.remove_item(i, amount_to_take_from_slot)
			ammount_collected += amount_to_take_from_slot

			if ammount_collected == max_amount_needed:
				break

	return ammount_collected

## When the single projectile reload timer ends, try and grab a bullet and see if we need to start it up again.
func _on_single_reload_timer_timeout() -> void:
	var reloads_left: int = single_reload_timer.get_meta("reloads_left")
	if reloads_left > 0:
		var ammo_available: int = _get_more_reload_ammo(1)
		if ammo_available == 1:
			s_stats.ammo_in_mag += ammo_available
			single_reload_timer.set_meta("reloads_left", reloads_left - 1)
			single_reload_timer.start(s_stats.single_proj_reload_time)
#endregion
