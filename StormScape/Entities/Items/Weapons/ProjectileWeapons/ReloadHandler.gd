extends Node
class_name ReloadHandler

signal reload_finished

var weapon: ProjectileWeapon
var anim_player: AnimationPlayer
var auto_decrementer: AutoDecrementer
var reload_dur_timer: Timer
var before_single_reload_timer: Timer


func initialize(parent_weapon: ProjectileWeapon) -> void:
	weapon = parent_weapon
	anim_player = weapon.anim_player
	auto_decrementer = weapon.source_entity.inv.auto_decrementer
	reload_dur_timer = TimerHelpers.create_one_shot_timer(weapon, -1)

	# When we don't have a before_single_reload anim but we do have the delay, use this timer instead
	before_single_reload_timer = TimerHelpers.create_one_shot_timer(weapon, -1, _on_reload_animation_finished.bind("before_single_reload"))

func _ready() -> void:
	if weapon.source_entity is Player:
		weapon.source_entity.inv.auto_decrementer.recharge_completed.connect(_on_ammo_recharge_delay_completed)

func attempt_reload() -> void:
	if weapon.stats.ammo_type in [ProjWeaponResource.ProjAmmoType.STAMINA, ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.CHARGES]:
		reload_finished.emit()
		return
	if not weapon.pullout_delay_timer.is_stopped() or _mag_is_full() or _get_more_reload_ammo(1, false) == 0:
		reload_finished.emit()
		return

	_start_reload_dur_timer()

	match weapon.stats.reload_type:
		ProjWeaponResource.ReloadType.MAGAZINE:
			_start_magazine_reload()
		ProjWeaponResource.ReloadType.SINGLE:
			_start_single_reload_delay()

func _start_reload_dur_timer() -> void:
	var total_reload_duration: float
	match weapon.stats.reload_type:
		ProjWeaponResource.ReloadType.MAGAZINE:
			total_reload_duration = weapon.stats.s_mods.get_stat("mag_reload_time")
		ProjWeaponResource.ReloadType.SINGLE:
			var needed: int = _get_needed_single_reloads_count()
			var single_proj_reload_time: float = weapon.stats.s_mods.get_stat("single_proj_reload_time")
			total_reload_duration = weapon.stats.before_single_reload_time + (needed * single_proj_reload_time)

	reload_dur_timer.start(total_reload_duration)

func cancel_reload() -> void:
	do_post_reload_animation_cleanup()
	reload_finished.emit()

func _start_magazine_reload() -> void:
	var reload_time: float = weapon.stats.s_mods.get_stat("mag_reload_time")
	_start_reload_animation("mag_reload", reload_time)

func _start_single_reload_delay() -> void:
	var delay_time: float = weapon.stats.before_single_reload_time
	if delay_time <= 0:
		_start_single_reload()
	else:
		if anim_player.has_animation("before_single_reload"):
			_start_reload_animation("before_single_reload", delay_time)
		else:
			before_single_reload_timer.start()

func _start_single_reload() -> void:
	var reloads_needed: int = _get_needed_single_reloads_count()
	var reload_time: float = weapon.stats.s_mods.get_stat("single_proj_reload_time")
	if reloads_needed > 1:
		_start_reload_animation("single_reload", reload_time)
	elif reloads_needed == 1:
		var anim_name: String = "final_single_reload"
		if not anim_player.has_animation(anim_name):
			anim_name = "single_reload"
		_start_reload_animation(anim_name, reload_time)
	else:
		do_post_reload_animation_cleanup()
		reload_finished.emit()

func _mag_is_full() -> bool:
	return weapon.stats.ammo_in_mag >= weapon.stats.s_mods.get_stat("mag_size")

## Searches through the source entity's inventory for more ammo to fill the magazine.
## Can optionally be used to only check for ammo when told not to take from the inventory when found.
func _get_more_reload_ammo(max_amount_needed: int, take_from_inventory: bool = true) -> int:
	if weapon.stats.ammo_type == ProjWeaponResource.ProjAmmoType.NONE:
		return max_amount_needed
	else:
		return weapon.source_entity.inv.get_more_ammo(max_amount_needed, take_from_inventory, weapon.stats.ammo_type)

func _start_reload_animation(anim_name: String, duration: float) -> void:
	# Sometimes overheat animation can mess with the scaling
	if anim_player.current_animation == "overheat":
		weapon.reset_animation_state()

	anim_player.speed_scale = 1.0 / duration
	weapon.source_entity.hands.off_hand_sprite.self_modulate.a = 0.0

	if anim_player.animation_finished.is_connected(_on_reload_animation_finished):
		anim_player.animation_finished.disconnect(_on_reload_animation_finished)
	anim_player.animation_finished.connect(_on_reload_animation_finished, CONNECT_ONE_SHOT)
	anim_player.play(anim_name)

func _on_reload_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"mag_reload":
			_complete_mag_reload()
		"before_single_reload":
			_start_single_reload()
		"single_reload":
			_complete_single_reload()
		"final_single_reload":
			_complete_single_reload()

func _complete_mag_reload() -> void:
	var mag_size: int = int(weapon.stats.s_mods.get_stat("mag_size"))
	var ammo_needed: int = mag_size - weapon.stats.ammo_in_mag
	var ammo_available: int = _get_more_reload_ammo(ammo_needed)
	weapon.update_mag_ammo(weapon.stats.ammo_in_mag + ammo_available)
	do_post_reload_animation_cleanup()
	reload_finished.emit()

func _complete_single_reload() -> void:
	var mag_size: int = int(weapon.stats.s_mods.get_stat("mag_size"))
	var ammo_needed: int = mag_size - weapon.stats.ammo_in_mag
	var reload_quantity: int = int(weapon.stats.s_mods.get_stat("single_reload_quantity"))
	var ammo_available: int = _get_more_reload_ammo(min(ammo_needed, reload_quantity))
	weapon.update_mag_ammo(weapon.stats.ammo_in_mag + ammo_available)

	if ammo_available <= 0:
		reload_finished.emit()
		return

	_start_single_reload()

func _get_needed_single_reloads_count() -> int:
	var mag_size: int = int(weapon.stats.s_mods.get_stat("mag_size"))
	var ammo_needed: int = mag_size - weapon.stats.ammo_in_mag
	var reload_quantity: int = int(weapon.stats.s_mods.get_stat("single_reload_quantity"))
	var reloads_needed: int = ceili(float(ammo_needed) / float(reload_quantity))
	return reloads_needed

## Reshows the hand component's off hand and hides the local reload hand. Also resets the animation state.
func do_post_reload_animation_cleanup() -> void:
	weapon.reset_animation_state()

	reload_dur_timer.stop()
	before_single_reload_timer.stop()
	update_reload_progress_ui()
	weapon.source_entity.hands.off_hand_sprite.self_modulate.a = 1.0

	if weapon.reload_off_hand:
		weapon.reload_off_hand.hide()
	if weapon.reload_main_hand:
		weapon.reload_main_hand.hide()

## When an ammo recharge delay is finished, this is called to resync the ammo in mag with the ammo ui.
func _on_ammo_recharge_delay_completed(item_id: StringName) -> void:
	if item_id != str(weapon.stats.session_uid):
		return
	weapon.update_mag_ammo(weapon.stats.ammo_in_mag)

## When we have recently fired, we should not instantly keep recharging ammo, so we send a cooldown to the recharger.
func restart_ammo_recharge_delay() -> void:
	auto_decrementer.update_recharge_delay(str(weapon.stats.session_uid), weapon.stats.auto_ammo_delay)

## This is called (usually after firing) to request a new ammo recharge instance. It is also called
## when first entering if we aren't at max ammo already.
func request_ammo_recharge() -> void:
	if weapon.stats.ammo_type in [ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.STAMINA]:
		return
	if weapon.stats.ammo_in_mag >= weapon.stats.s_mods.get_stat("mag_size"):
		return

	var recharge_dur: float = weapon.stats.s_mods.get_stat("auto_ammo_interval")
	if recharge_dur <= 0:
		return
	auto_decrementer.request_recharge(str(weapon.stats.session_uid), weapon.stats)

func update_reload_progress_ui() -> void:
	if (weapon.overhead_ui == null) or (weapon.stats.hide_reload_ui):
		return

	if reload_dur_timer.is_stopped():
		weapon.overhead_ui.update_reload_progress(0)

		# Only want to update the cursor tint here if we aren't allowed to show cooldowns on the cursor tint
		if not weapon.stats.show_cursor_cooldown:
			CursorManager.update_vertical_tint_progress(0)
		return

	var total_reload: float = reload_dur_timer.wait_time
	var time_left: float = reload_dur_timer.time_left
	var progress: int = int((1.0 - (time_left / total_reload)) * 100)

	weapon.overhead_ui.update_reload_progress(progress)

	# Only want to show the reload on the cursor tint if we aren't allowed to show cooldowns on the cursor tint
	if not weapon.stats.show_cursor_cooldown:
		CursorManager.update_vertical_tint_progress(progress)
