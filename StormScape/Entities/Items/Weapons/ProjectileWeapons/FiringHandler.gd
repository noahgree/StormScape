extends Node
class_name FiringHandler

signal firing_started
signal firing_ended

var weapon: ProjectileWeapon
var auto_decrementer: AutoDecrementer
var mouse_area_scan_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.01, _on_mouse_area_scan_delay_timer_timeout)
var hitscan_hands_freeze_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_hitscan_hands_freeze_timer_timeout) ## The timer that tracks the brief moment after a semi-auto hitscan shot that we shouldn't be rotating.
const HITSCAN_HANDS_FREEZE_DURATION: float = 0.065


func initialize(new_weapon: ProjectileWeapon) -> void:
	weapon = new_weapon
	auto_decrementer = weapon.source_entity.inv.auto_decrementer

func start_firing() -> void:
	firing_started.emit()
	await _handle_bursting()
	firing_ended.emit()

func _handle_bursting() -> void:
	var bursts: int = int(weapon.stats.s_mods.get_stat("projectiles_per_fire"))

	# If we only need to add it once, do it now, otherwise do it for every shot in the below loop
	if not weapon.stats.add_overheat_per_burst_shot:
		weapon.overheat_handler.add_overheat()
	if not weapon.stats.add_bloom_per_burst_shot:
		_add_bloom()

	for burst_index: int in range(bursts):
		if weapon.stats.add_overheat_per_burst_shot:
			weapon.overheat_handler.add_overheat()
		if weapon.stats.add_bloom_per_burst_shot:
			_add_bloom()

		await _handle_barraging()

		if burst_index < bursts - 1:
			var burst_delay: float = weapon.stats.burst_proj_delay
			await get_tree().create_timer(burst_delay, false).timeout

func _handle_barraging() -> void:
	var barrage_count: int = weapon.stats.s_mods.get_stat("barrage_count")
	var angular_spread_rads: float = deg_to_rad(weapon.stats.s_mods.get_stat("angular_spread"))

	# If the spread is close to a full circle, decrease the width between the spreads so they don't overlap near 360º
	var close_to_360_adjustment: int = 0 if angular_spread_rads > 5.41 else 1
	var spread_segment_width: float = angular_spread_rads / (barrage_count - close_to_360_adjustment)

	# Make sure each projectile in this barrage shares the same multishot ID
	var multishot_id: int = UIDHelper.generate_multishot_uid()

	for i: int in range(barrage_count):
		# Start at the top angle of the barrage by subtracting half the total width from the current rotation
		var start_rot: float = weapon.global_rotation - (angular_spread_rads * 0.5)
		var proj_rot: float = start_rot + (i * spread_segment_width)
		if weapon.stats.do_cluster_barrage:
			proj_rot = start_rot + randf_range(0, angular_spread_rads)

		if not weapon.stats.use_hitscan:
			_spawn_projectile(proj_rot, multishot_id)
		else:
			var start_of_hitscan_rotation_offsets: float = -angular_spread_rads * 0.5
			_spawn_hitscan(i, spread_segment_width, start_of_hitscan_rotation_offsets)

		if (weapon.stats.barrage_proj_delay > 0) and (i < barrage_count - 1):
			await get_tree().create_timer(weapon.stats.barrage_proj_delay, false).timeout

func _spawn_projectile(proj_rot: float, multishot_id: int) -> void:
	var total_proj_rot: float = proj_rot + _get_bloom_to_add_radians()
	var proj: Projectile = Projectile.create(weapon.stats, weapon.source_entity, weapon.proj_origin_node.global_position, total_proj_rot)
	proj.multishot_id = multishot_id

	if weapon.stats.projectile_logic.homing_method == "Mouse Position":
		weapon.mouse_scan_area_targets.clear()
		weapon.enable_mouse_area()
		mouse_area_scan_delay_timer.add_meta("proj", proj)
		mouse_area_scan_delay_timer.start()
	else:
		Globals.world_root.add_child(proj)

func _spawn_hitscan(barrage_index: int, spread_segment_width: float, start_of_offsets: float) -> void:
	var rotation_offset: float = start_of_offsets + (barrage_index * spread_segment_width)
	if weapon.stats.do_cluster_barrage:
		rotation_offset = randf() * spread_segment_width
	rotation_offset += _get_bloom_to_add_radians()

	var hitscan: Hitscan = Hitscan.create(weapon, rotation_offset)
	Globals.world_root.add_child(hitscan)
	weapon.current_hitscans.append(hitscan)

	# Freezing the hand rotation during semi auto or very brief automatic hitscans
	if weapon.stats.firing_mode == ProjWeaponResource.FiringType.SEMI_AUTO:
		weapon.source_entity.hands.should_rotate = false
	elif weapon.stats.firing_mode == ProjWeaponResource.FiringType.AUTO and weapon.stats.s_mods.get_stat("hitscan_duration") <= HITSCAN_HANDS_FREEZE_DURATION:
		weapon.source_entity.hands.should_rotate = false
	else:
		return
	hitscan_hands_freeze_timer.start(HITSCAN_HANDS_FREEZE_DURATION)

func _on_hitscan_hands_freeze_timer_timeout() -> void:
	weapon.source_slot.hands.should_rotate = true

func _on_mouse_area_scan_delay_timer_timeout() -> void:
	var proj: Projectile = mouse_area_scan_delay_timer.get_meta("proj")
	mouse_area_scan_delay_timer.set_meta("proj", null)

	# Duplicate to ensure later changes don't alter the same array now attached to the projectile
	proj.mouse_scan_targets = weapon.mouse_scan_area_targets.duplicate()
	weapon.disable_mouse_area()
	Globals.world_root.add_child(proj)

## Grabs a point from the bloom curve based on current bloom level given by the auto decrementer.
func _get_bloom_to_add_radians() -> float:
	var current_bloom: float = auto_decrementer.get_bloom(str(weapon.stats.session_uid))
	if current_bloom > 0:
		var deviation: float = weapon.stats.bloom_curve.sample_baked(current_bloom)
		var random_direction: int = 1 if randf() < 0.5 else -1
		var max_current_bloom: float = deviation * weapon.stats.s_mods.get_stat("max_bloom")
		var random_amount_of_max_current_bloom: float = max_current_bloom * random_direction * randf()
		return deg_to_rad(random_amount_of_max_current_bloom)
	else:
		return 0

## Increases current bloom level via sampling the increase curve using the current bloom.
func _add_bloom() -> void:
	if weapon.stats.s_mods.get_stat("max_bloom") <= 0:
		return

	var current_bloom: float = auto_decrementer.get_bloom(str(weapon.stats.session_uid))
	var sampled_point: float = weapon.stats.bloom_increase_rate.sample_baked(current_bloom)
	var increase_rate_multiplier: float = weapon.stats.s_mods.get_stat("bloom_increase_rate_multiplier")
	var increase_amount: float = max(0.01, sampled_point * increase_rate_multiplier)
	auto_decrementer.add_bloom(
		str(weapon.stats.session_uid),
		min(1, (increase_amount)),
		weapon.stats.bloom_decrease_rate,
		weapon.stats.bloom_decrease_delay
		)
