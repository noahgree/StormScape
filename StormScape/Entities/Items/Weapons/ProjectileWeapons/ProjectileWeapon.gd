extends Weapon
class_name ProjectileWeapon
## Base class for all weapons that spawn any sort of projectile or hitscan or AOE.

@export var proj_origin: Vector2 = Vector2.ZERO: ## Where the projectile spawns from in local space of the weapon scene.
	set(new_origin):
		proj_origin = new_origin
		if proj_origin_node:
			proj_origin_node.position = proj_origin
@export var vfx_scene: PackedScene = load("res://Entities/Items/Weapons/WeaponVFX/Simple/SimpleVFX.tscn")

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this projectile weapon.
@onready var proj_origin_node: Marker2D = $ProjectileOrigin ## The point at which projectiles should spawn from.

#region Local Vars
var firing_duration_timer: Timer = Timer.new() ## The timer tracking how long after we press fire before the proj spawns.
var reload_timer: Timer = Timer.new() ## The timer tracking the delay between reload start and end.
var single_reload_timer: Timer = Timer.new() ## The timer tracking the delay between single bullet reloads.
var hitscan_hands_freeze_timer: Timer = Timer.new() ## The timer that tracks the brief moment after a semi-auto hitscan shot that we shouldn't be rotating.
var hold_just_released: bool = false ## Whether the mouse hold was just released.
var is_reloading: bool = false: ## Whether some reload method is currently in progress.
	set(new_value):
		is_reloading = new_value
		if is_reloading and reloading_ui:
			reloading_ui.show()
		elif reloading_ui:
			reloading_ui.hide()
var is_reloading_single_and_has_since_released: bool = true ## Whether we've begun reloading one bullet at a time and have relased the mouse since starting.
var is_charging: bool = false ## Whether the weapon is currently charging up for a charge shot.
var hitscan_delay: float = 0 ## The calculated delay to be used instead of just the fire cooldown when using hitscans.
var is_holding_hitscan: bool = false: ## Whether we are currently holding down the fire button and keeping the hitscan alive.
	set(new_value):
		is_holding_hitscan = new_value
		if new_value == false: _clean_up_hitscans()
var current_hitscans: Array[Hitscan] = [] ## The currently spawned array of hitscans to get cleaned up when we unequip this weapon.
var mouse_scan_area_targets: Array[Node] = [] ## The array of potential targets found and passed to the proj when using the "Mouse Position" homing method.
var mouse_area: Area2D ## The area around the mouse that scans for targets when using the "Mouse Position" homing method
var reloading_ui: Control ## The UI showing the reloading in progress. Only applicable and non-null for players.
#endregion


#region Core
## Sets the new stats by duplicating the old ones (to ensure unique resource instance) and sets up the cache if we haven't already.
func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

	# Duplicates the cache & effect sources to be unique and then calls for the cache to get loaded.
	# stats.cache_is_setup gets set to true the first time the cache is setup on first load. From there on it is saved as true even during in-game save and loads.
	if not stats.cache_is_setup:
		stats.s_mods = stats.s_mods.duplicate()
		stats.effect_source = stats.effect_source.duplicate()
		stats.charge_effect_source = stats.charge_effect_source.duplicate()
		stats.original_status_effects = stats.effect_source.status_effects.duplicate()
		stats.original_charge_status_effects = stats.charge_effect_source.status_effects.duplicate()
		_setup_mod_cache()

## Sets up the base values for the stat mod cache so that weapon mods can be added and managed properly.
func _setup_mod_cache() -> void:
	var normal_moddable_stats: Dictionary[StringName, float] = {
		&"fire_cooldown" : stats.fire_cooldown,
		&"mag_size" : stats.mag_size,
		&"mag_reload_time" : stats.mag_reload_time,
		&"single_proj_reload_time" : stats.single_proj_reload_time,
		&"single_reload_quantity" : stats.single_reload_quantity,
		&"auto_ammo_interval" : stats.auto_ammo_interval,
		&"auto_ammo_count" : stats.auto_ammo_count,
		&"pullout_delay" : stats.pullout_delay,
		&"max_bloom" : stats.max_bloom,
		&"bloom_increase_rate_multiplier" : 1.0,
		&"bloom_decrease_rate_multiplier" : 1.0,
		&"initial_fire_rate_delay" : stats.initial_fire_rate_delay,
		&"warmup_increase_rate_multiplier" : 1.0,
		&"overheat_penalty" : stats.overheat_penalty,
		&"overheat_increase_rate_multiplier" : 1.0,
		&"projectiles_per_fire" : stats.projectiles_per_fire,
		&"barrage_count" : stats.barrage_count,
		&"angular_spread" : stats.angular_spread,
		&"base_damage" : stats.effect_source.base_damage,
		&"base_healing" : stats.effect_source.base_healing,
		&"crit_chance" : stats.effect_source.crit_chance,
		&"armor_penetration" : stats.effect_source.armor_penetration,
		&"proj_speed" : stats.projectile_logic.speed,
		&"proj_max_distance" : stats.projectile_logic.max_distance,
		&"proj_max_pierce" : stats.projectile_logic.max_pierce,
		&"proj_max_ricochet" : stats.projectile_logic.max_ricochet,
		&"proj_max_turn_rate" : stats.projectile_logic.max_turn_rate,
		&"proj_homing_duration" : stats.projectile_logic.homing_duration,
		&"proj_arc_travel_distance" : stats.projectile_logic.arc_travel_distance,
		&"proj_bounce_count" : stats.projectile_logic.bounce_count,
		&"proj_aoe_radius" : stats.projectile_logic.aoe_radius,
		&"hitscan_duration" : stats.hitscan_logic.hitscan_duration,
		&"hitscan_effect_interval" : stats.hitscan_logic.hitscan_effect_interval,
		&"hitscan_pierce_count" : stats.hitscan_logic.hitscan_pierce_count,
		&"hitscan_max_distance" : stats.hitscan_logic.hitscan_max_distance
	}
	var charge_moddable_stats: Dictionary[StringName, float] = {
		&"min_charge_time" : stats.min_charge_time,
		&"charge_fire_cooldown" : stats.charge_fire_cooldown,
		&"charge_base_damage" : stats.charge_effect_source.base_damage,
		&"charge_base_healing" : stats.charge_effect_source.base_healing,
		&"charge_crit_chance" : stats.charge_effect_source.crit_chance,
		&"charge_armor_penetration" : stats.charge_effect_source.armor_penetration,
		&"charge_proj_speed" : stats.charge_projectile_logic.speed,
		&"charge_proj_max_distance" : stats.charge_projectile_logic.max_distance,
		&"charge_proj_max_pierce" : stats.charge_projectile_logic.max_pierce,
		&"charge_proj_max_ricochet" : stats.charge_projectile_logic.max_ricochet,
		&"charge_proj_max_turn_rate" : stats.charge_projectile_logic.max_turn_rate,
		&"charge_proj_homing_duration" : stats.charge_projectile_logic.homing_duration,
		&"charge_proj_arc_travel_distance" : stats.charge_projectile_logic.arc_travel_distance,
		&"charge_proj_bounce_count" : stats.charge_projectile_logic.bounce_count,
		&"charge_proj_aoe_radius" : stats.charge_projectile_logic.aoe_radius,
		&"charge_hitscan_duration" : stats.charge_hitscan_logic.hitscan_duration,
		&"charge_hitscan_max_distance" : stats.charge_hitscan_logic.hitscan_max_distance,
		&"charge_hitscan_effect_interval" : stats.charge_hitscan_logic.hitscan_effect_interval,
		&"charge_hitscan_pierce_count" : stats.charge_hitscan_logic.hitscan_pierce_count
	}

	stats.s_mods.add_moddable_stats(normal_moddable_stats)
	stats.s_mods.add_moddable_stats(charge_moddable_stats)
	stats.cache_is_setup = true

func _ready() -> void:
	super._ready()

	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
		if source_entity is DynamicEntity and not stats.hide_ammo_ui:
			source_entity.stamina_component.stamina_changed.connect(_update_ammo_ui)
	elif stats.ammo_type != ProjWeaponResource.ProjAmmoType.SELF and stats.ammo_type != ProjWeaponResource.ProjAmmoType.CHARGES:
		if source_entity is Player and not stats.hide_reload_ui:
			reloading_ui = source_entity.get_node("ReloadingUI")

	source_entity.inv.auto_decrementer.cooldown_ended.connect(_on_fire_cooldown_timeout)
	source_entity.inv.auto_decrementer.recharge_completed.connect(_on_ammo_recharge_completed)

	add_child(firing_duration_timer)
	add_child(reload_timer)
	add_child(single_reload_timer)
	add_child(hitscan_hands_freeze_timer)
	firing_duration_timer.one_shot = true
	reload_timer.one_shot = true
	single_reload_timer.one_shot = true
	hitscan_hands_freeze_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_timer_timeout)
	single_reload_timer.timeout.connect(_on_single_reload_timer_timeout)
	hitscan_hands_freeze_timer.timeout.connect(_on_hitscan_hands_freeze_timer_timeout)

func disable() -> void:
	source_entity.move_fsm.should_rotate = true
	source_entity.hands.equipped_item_should_follow_mouse = true
	is_holding_hitscan = false
	is_reloading_single_and_has_since_released = true

	if stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal(stats.charging_stat_effect.effect_name)
	is_charging = false

func enter() -> void:
	if stats.s_mods.base_values.is_empty():
		_setup_mod_cache()

	if (stats.ammo_in_mag == -1) and (stats.ammo_type != ProjWeaponResource.ProjAmmoType.STAMINA):
		stats.ammo_in_mag = stats.s_mods.get_stat("mag_size")
	else:
		_get_has_needed_ammo_and_reload_if_not()
	_update_ammo_ui()

	if stats.ammo_type != ProjWeaponResource.ProjAmmoType.SELF and stats.ammo_type != ProjWeaponResource.ProjAmmoType.STAMINA:
		if stats.ammo_in_mag < stats.s_mods.get_stat("mag_size"):
			_request_ammo_recharge()

	_check_if_needs_mouse_area_scanner()

	if stats.weapon_mods_need_to_be_readded_after_save:
		for weapon_mod: WeaponMod in stats.current_mods.values():
			weapon_mod_manager.handle_weapon_mod(weapon_mod)
		stats.weapon_mods_need_to_be_readded_after_save = false

func exit() -> void:
	source_entity.move_fsm.should_rotate = true
	source_entity.hands.equipped_item_should_follow_mouse = true
	_clean_up_hitscans()
	if mouse_area: mouse_area.queue_free()

	if stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal(stats.charging_stat_effect.effect_name)

## If we are set to do mouse position-based homing, we set up the mouse area and its signals and add it as a child.
func _check_if_needs_mouse_area_scanner() -> void:
	if not stats.use_hitscan and stats.projectile_logic.homing_method == "Mouse Position":
		mouse_area = Area2D.new()
		var collision_shape: CollisionShape2D = CollisionShape2D.new()
		var circle_shape: CircleShape2D = CircleShape2D.new()

		mouse_area.collision_layer = 0
		mouse_area.collision_mask = stats.effect_source.scanned_phys_layers
		mouse_area.area_entered.connect(func(area: Area2D) -> void: mouse_scan_area_targets.append(area))
		mouse_area.body_entered.connect(func(body: Node2D) -> void: mouse_scan_area_targets.append(body))

		circle_shape.radius = stats.projectile_logic.mouse_target_radius
		collision_shape.shape = circle_shape
		collision_shape.disabled = true
		mouse_area.add_child(collision_shape)
		mouse_area.global_position = get_global_mouse_position()
		GlobalData.world_root.add_child(mouse_area)

func _enable_mouse_area() -> void:
	if mouse_area: mouse_area.get_child(0).disabled = false

func _disable_mouse_area() -> void:
	if mouse_area: mouse_area.get_child(0).disabled = true

## Every frame we decrease the warmup and the bloom levels based on their decrease curves.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if reloading_ui and is_reloading:
		reloading_ui.update_progress((1 - (reload_timer.time_left / reload_timer.wait_time)) * 100)

func _physics_process(_delta: float) -> void:
	if mouse_area != null:
		mouse_area.global_position = get_global_mouse_position()

## When the cooldown manager from the hands component fires a signal with the matching item id, process the aftermath.
func _on_fire_cooldown_timeout(item_id: StringName) -> void:
	if item_id != stats.get_cooldown_id():
		return

	if is_holding_hitscan:
		_fire()
		_handle_adding_cooldown(stats.s_mods.get_stat("fire_cooldown") + hitscan_delay)
	else:
		_clean_up_hitscans()

## This is the standard method of triggering a cooldown, but child proj weapon scripts can override this if they want to
## do something else or skip cooldowns. For example, Unique Proj Weapons override this to prevent visuals from updating.
func _update_cooldown_with_potential_visuals(duration: float) -> void:
	_handle_adding_cooldown(duration)
#endregion

#region Called From HandsComponent
## Called from the hands component when the mouse is clicked.
func activate() -> void:
	if not pullout_delay_timer.is_stopped() or (not reload_timer.is_stopped() and stats.reload_type == "Magazine"):
		return

	is_reloading_single_and_has_since_released = true

	if stats.firing_mode == "Semi Auto":
		_fire()

## Called from the hands component when the mouse is held down. Includes how long it has been held down so far.
func hold_activate(_hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or (not reload_timer.is_stopped() and stats.reload_type == "Magazine") or not firing_duration_timer.is_stopped():
		source_entity.hands.been_holding_time = 0
		return

	if stats.firing_mode == "Auto":
		_fire()
	elif stats.firing_mode == "Charge":
		if not is_charging and stats.charging_stat_effect != null:
			var effect: StatusEffect = stats.charging_stat_effect.duplicate()
			effect.mod_time = 100000000
			source_entity.effect_receiver.handle_status_effect(effect)
			is_charging = true

## Called from the hands component when we release the mouse. Includes how long we had it held down.
func release_hold_activate(hold_time: float) -> void:
	if stats.firing_mode == "Auto" and stats.allow_hitscan_holding and is_holding_hitscan:
		is_holding_hitscan = false

	if not pullout_delay_timer.is_stopped() or (not reload_timer.is_stopped() and stats.reload_type == "Magazine"):
		source_entity.hands.been_holding_time = 0
		return

	is_reloading_single_and_has_since_released = true

	if stats.firing_mode == "Charge":
		if stats.charging_stat_effect != null:
			source_entity.effects.request_effect_removal(stats.charging_stat_effect.effect_name)
		_charge_fire(hold_time)
		is_charging = false

	hold_just_released = true

## Called from the hands component to try and start a reload.
func reload() -> void:
	if (stats.ammo_type != ProjWeaponResource.ProjAmmoType.STAMINA
		and stats.ammo_type != ProjWeaponResource.ProjAmmoType.SELF
		and stats.ammo_type != ProjWeaponResource.ProjAmmoType.CHARGES):
		if pullout_delay_timer.is_stopped() and reload_timer.is_stopped() and single_reload_timer.is_stopped():
			if not is_reloading and not stats.ammo_in_mag >= stats.s_mods.get_stat("mag_size"):
				_attempt_reload()
#endregion

#region Firing Activations
## Check if we can do a normal firing, and if we can, start it.
func _fire() -> void:
	if _get_cooldown() > 0:
		return
	if not is_reloading_single_and_has_since_released:
		is_holding_hitscan = false
		return
	if not _get_has_needed_ammo_and_reload_if_not(false):
		is_holding_hitscan = false
		return

	single_reload_timer.stop()
	is_reloading = false

	if _get_warmup_firing_delay() > 0:
		_handle_adding_cooldown(_get_warmup_firing_delay())
		while _get_cooldown() > 0: # Signal fires for all ending cooldowns, so we loop until ours has ended
			await source_entity.inv.auto_decrementer.cooldown_ended

		if hold_just_released:
			hold_just_released = false
			return

	if not firing_duration_timer.is_stopped():
		return
	else:
		firing_duration_timer.start(max(0.05, stats.firing_duration))
		_start_firing_anim(false)
		await firing_duration_timer.timeout

	_set_up_hitscan(false)
	_handle_warmup_increase()
	if not is_holding_hitscan:
		_apply_burst_logic(false)
	else:
		_apply_ammo_consumption(int(stats.s_mods.get_stat("projectiles_per_fire")), false)
	_apply_post_firing_effect(false)
	_get_has_needed_ammo_and_reload_if_not(false)
	_notify_recharge_of_a_recent_firing()

	if stats.use_hitscan and stats.allow_hitscan_holding and stats.firing_mode == "Auto" and not is_holding_hitscan:
		is_holding_hitscan = true
		GlobalData.player_camera.update_persistent_shake_strength(stats.firing_cam_shake_str)

## Check if we can do a charge firing, and if we can, start it.
func _charge_fire(hold_time: float) -> void:
	if not _get_has_needed_ammo_and_reload_if_not(true):
		source_entity.hands.been_holding_time = 0
		return

	if (hold_time >= stats.s_mods.get_stat("min_charge_time")) and (hold_time > 0) and _get_cooldown() == 0:
		firing_duration_timer.start(max(0.05, stats.charge_firing_duration))
		_start_firing_anim(true)
		await firing_duration_timer.timeout

		_set_up_hitscan(true)
		_apply_burst_logic(true)
		_apply_post_firing_effect(true)
		_get_has_needed_ammo_and_reload_if_not(true)
		_notify_recharge_of_a_recent_firing()

		while _get_cooldown() > 0: # Signal fires for all ending cooldowns, so we loop until ours has ended
			await source_entity.inv.auto_decrementer.cooldown_ended
		source_entity.hands.been_holding_time = 0

## Set up the delay we will use if we have a non-holding or charged hitscan. This basically increases the shot duration.
func _set_up_hitscan(was_charge_fire: bool = false) -> void:
	if not stats.use_hitscan:
		hitscan_delay = 0
	else:
		if not stats.allow_hitscan_holding or was_charge_fire:
			hitscan_delay = stats.s_mods.get_stat("hitscan_duration") if not was_charge_fire else stats.s_mods.get_stat("charge_hitscan_duration")
		else:
			hitscan_delay = 0

## When hitscans have ended or we swap off the weapon, remove persistent cam fx and free the hitscan itself.
func _clean_up_hitscans() -> void:
	if not current_hitscans.is_empty():
		GlobalData.player_camera.update_persistent_shake_strength(-stats.firing_cam_shake_str)

	for hitscan: Variant in current_hitscans:
		if is_instance_valid(hitscan):
			hitscan.queue_free()
	current_hitscans.clear()

## When the timer that runs when we shouldn't follow the mouse (because of an active hitscan) ends, allow mouse following again.
func _on_hitscan_hands_freeze_timer_timeout() -> void:
	source_entity.hands.equipped_item_should_follow_mouse = true
#endregion

#region Projectile Spawning
## Applies bursting logic to potentially shoot more than one projectile at a short, set interval.
func _apply_burst_logic(was_charge_fire: bool = false) -> void:
	if stats.s_mods.get_stat("projectiles_per_fire") > 1:
		if not stats.add_bloom_per_burst_shot: _handle_bloom_increase(was_charge_fire)
		if not stats.add_overheat_per_burst_shot: _handle_overheat_increase(was_charge_fire)
	var shots: int = int(stats.s_mods.get_stat("projectiles_per_fire"))

	var delay: float = 0
	if _get_warmup_firing_delay() > 0:
		delay = _get_warmup_firing_delay()
	else:
		if stats.firing_mode == "Auto" or stats.firing_mode == "Semi Auto":
			delay = stats.s_mods.get_stat("fire_cooldown") + hitscan_delay
		elif stats.firing_mode == "Charge":
			delay = stats.s_mods.get_stat("charge_fire_cooldown") + hitscan_delay

	if not stats.use_hitscan:
		delay += (stats.burst_bullet_delay * (shots - 1))

	if delay > 0: _update_cooldown_with_potential_visuals(delay)

	_apply_ammo_consumption(shots, was_charge_fire)

## Calls to consume ammo based on how many shots we performed.
func _apply_ammo_consumption(shot_count: int, was_charge_fire: bool = false) -> void:
	if stats.dont_consume_ammo:
		_handle_per_shot_delay_and_bloom(shot_count, was_charge_fire, (not is_holding_hitscan))
		return

	if not was_charge_fire:
		if stats.use_ammo_per_burst_proj:
			for i: int in range(shot_count):
				_consume_ammo(1)
		else:
			_consume_ammo(1)
	else:
		_consume_ammo(stats.ammo_use_per_charge)

	_handle_per_shot_delay_and_bloom(shot_count, was_charge_fire, (not is_holding_hitscan))

## Calls to increase the bloom and awaits burst bullet delays if we have them. Can be told not to spawn afterwards as well.
func _handle_per_shot_delay_and_bloom(shot_count: int, was_charge_fire: bool = false, proceed_to_spawn: bool = true) -> void:
	for i: int in range(shot_count):
		if stats.add_bloom_per_burst_shot or (stats.s_mods.get_stat("projectiles_per_fire") == 1):
			_handle_bloom_increase(false) # Never trigger charge fire mult if we are bursting
		if stats.add_overheat_per_burst_shot or (stats.s_mods.get_stat("projectiles_per_fire") == 1):
			_handle_overheat_increase(false) # Never trigger charge fire mult if we are bursting

		if proceed_to_spawn:
			_apply_barrage_logic(was_charge_fire)

			if i != (shot_count - 1):
				await get_tree().create_timer(max(0.03, stats.burst_bullet_delay), false, true, false).timeout

## Applies barrage logic to potentially spawn multiple projectiles at a specific angle apart.
func _apply_barrage_logic(was_charge_fire: bool = false) -> void:
	var effect_src: EffectSource = stats.effect_source if not was_charge_fire else stats.charge_effect_source

	var angular_spread_radians: float = deg_to_rad(stats.s_mods.get_stat("angular_spread"))
	var close_to_360_adjustment: int = 0 if stats.s_mods.get_stat("angular_spread") > 310 else 1
	var spread_segment_width: float = angular_spread_radians / (stats.s_mods.get_stat("barrage_count") - close_to_360_adjustment)
	var start_rotation: float = global_rotation - (angular_spread_radians / 2.0)
	#var multishot_id: int = UIDHelper.generate_multishot_uid()

	for i: int in range(stats.barrage_count):
		if not stats.use_hitscan:
			var rotation_adjustment: float = start_rotation + (i * spread_segment_width)
			var proj: Projectile = Projectile.create(stats, source_entity, proj_origin_node.global_position, global_rotation, was_charge_fire)
			proj.rotation = rotation_adjustment if stats.s_mods.get_stat("barrage_count") > 1 else proj.rotation
			proj.starting_proj_height = -(source_entity.hands.position.y + proj_origin.y) / 2

			if stats.projectile_logic.homing_method == "Mouse Position":
				mouse_scan_area_targets.clear()
				_enable_mouse_area()
				var tree: SceneTree = get_tree()
				for j: int in range(2): await tree.physics_frame
				proj.mouse_scan_targets = mouse_scan_area_targets
				call_deferred("_disable_mouse_area")

			_spawn_projectile(proj)
		else:
			var hitscan_scene: PackedScene = stats.hitscan_logic.hitscan_scn
			if was_charge_fire and stats.charge_hitscan_logic != null and stats.charge_hitscan_logic.hitscan != null:
				hitscan_scene = stats.charge_hitscan_logic.hitscan_scn

			var rotation_adjustment: float = -angular_spread_radians / 2 + (i * spread_segment_width)
			var hitscan: Hitscan = Hitscan.create(hitscan_scene, effect_src, self, source_entity, proj_origin_node.global_position, rotation_adjustment if stats.s_mods.get_stat("barrage_count") > 1 else 0.0, was_charge_fire)
			_spawn_hitscan(hitscan)

	_do_firing_fx(was_charge_fire)

## Spawns the projectile that has been passed to it. Reloads if we don't have enough for the next activation.
func _spawn_projectile(proj: Projectile) -> void:
	proj.rotation += deg_to_rad(_get_bloom())

	GlobalData.world_root.add_child(proj)

## Spawns the hitscan that has been passed to it. Reloads if we don't have enough for the next activation.
func _spawn_hitscan(hitscan: Hitscan) -> void:
	hitscan.rotation_offset += deg_to_rad(_get_bloom())
	GlobalData.world_root.add_child(hitscan)
	current_hitscans.append(hitscan)

	if stats.firing_mode == "Semi Auto" or (stats.firing_mode == "Auto" and stats.s_mods.get_stat("hitscan_duration") < 0.65):
		source_entity.hands.equipped_item_should_follow_mouse = false
		hitscan_hands_freeze_timer.start(0.065)
#endregion

#region Warmup & Bloom & Cooldown & Overheat
## Increases current warmup level via sampling the increase curve using the current warmup.
func _handle_warmup_increase() -> void:
	if stats.s_mods.get_stat("initial_fire_rate_delay") > 0 and stats.firing_mode == "Auto":
		var current_warmup: float = source_entity.inv.auto_decrementer.get_warmup(str(stats.session_uid))
		var sampled_point: float = stats.warmup_increase_rate.sample_baked(current_warmup)
		var increase_amount: float = max(0.01, sampled_point * stats.s_mods.get_stat("warmup_increase_rate_multiplier"))
		source_entity.inv.auto_decrementer.add_warmup(
			StringName(str(stats.session_uid)),
			min(1, increase_amount),
			stats.warmup_decrease_rate,
			stats.warmup_decrease_delay)

## Grabs a point from the warmup curve based on current warmup level given by the auto decrementer.
func _get_warmup_firing_delay() -> float:
	var current_warmup: float = source_entity.inv.auto_decrementer.get_warmup(str(stats.session_uid))
	if current_warmup > 0:
		var sampled_delay: float = stats.warmup_delay_curve.sample_baked(current_warmup)
		return (sampled_delay * stats.s_mods.get_stat("initial_fire_rate_delay")) + hitscan_delay
	else:
		return 0

## Increases current bloom level via sampling the increase curve using the current bloom.
func _handle_bloom_increase(was_charge_fire: bool = false) -> void:
	if stats.s_mods.get_stat("max_bloom") > 0:
		var current_bloom: float = source_entity.inv.auto_decrementer.get_bloom(str(stats.session_uid))
		var sampled_point: float = stats.bloom_increase_rate.sample_baked(current_bloom)
		var increase_amount: float = max(0.01, sampled_point * stats.s_mods.get_stat("bloom_increase_rate_multiplier"))
		var charge_shot_mult: float = 1.0 if not was_charge_fire else stats.charge_bloom_mult
		source_entity.inv.auto_decrementer.add_bloom(
			StringName(str(stats.session_uid)),
			min(1, (increase_amount * charge_shot_mult)),
			stats.bloom_decrease_rate,
			stats.bloom_decrease_delay)

## Grabs a point from the bloom curve based on current bloom level given by the auto decrementer.
func _get_bloom() -> float:
	var current_bloom: float = source_entity.inv.auto_decrementer.get_bloom(str(stats.session_uid))
	if current_bloom > 0:
		var deviation: float = stats.bloom_curve.sample_baked(current_bloom)
		var random_direction: int = 1 if randf() < 0.5 else -1
		return deviation * stats.s_mods.get_stat("max_bloom") * random_direction * randf()
	else:
		return 0

## Adds a cooldown to the auto decrementer for the current cooldown id.
func _handle_adding_cooldown(duration: float) -> void:
	source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), duration)

## Gets a current cooldown level from the auto decrementer based on the cooldown id.
func _get_cooldown() -> float:
	return source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id())

## Increases current overheat level via sampling the increase curve using the current overheat.
func _handle_overheat_increase(was_charge_fire: bool = false) -> void:
	if stats.s_mods.get_stat("overheat_penalty") > 0:
		var current_overheat: float = source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid))
		var sampled_point: float = stats.overheat_inc_rate.sample_baked(current_overheat)
		var increase_amount: float = max(0.005, sampled_point * stats.s_mods.get_stat("overheat_increase_rate_multiplier"))
		var charge_shot_mult: float = 1.0 if not was_charge_fire else stats.charge_overheat_mult
		source_entity.inv.auto_decrementer.add_overheat(
			StringName(str(stats.session_uid)),
			min(1, (increase_amount * charge_shot_mult)),
			stats.overheat_dec_rate,
			stats.overheat_dec_delay)

		if source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid)) >= 1:
			_handle_max_overheat_reached()

## When we reach max overheat, add a cooldown of some kind.
func _handle_max_overheat_reached() -> void:
	_handle_adding_cooldown(stats.s_mods.get_stat("overheat_penalty"))
#endregion

#region FX & Animations
## Start the sounds and vfx that should play when firing.
func _do_firing_fx(with_charge_mult: bool = false) -> void:
	var multiplier: float = stats.charge_cam_fx_mult if with_charge_mult else 1.0
	var fire_cooldown: float = stats.s_mods.get_stat("fire_cooldown")
	if stats.firing_cam_shake_dur > 0:
		var dur: float = min(stats.firing_cam_shake_dur, max(0, fire_cooldown + hitscan_delay - 0.01))
		GlobalData.player_camera.start_shake(stats.firing_cam_shake_str * multiplier, dur * multiplier)
	if stats.firing_cam_freeze_dur > 0:
		var dur: float = min(stats.firing_cam_freeze_dur, max(0, fire_cooldown + hitscan_delay - 0.01))
		GlobalData.player_camera.start_freeze(stats.firing_cam_freeze_mult * multiplier, dur * multiplier)

	var sound: String = stats.firing_sound if not with_charge_mult else stats.charge_firing_sound
	if sound != "": AudioManager.play_sound(sound, AudioManager.SoundType.SFX_2D, global_position)

	if stats.muzzle_flash != null and vfx_scene != null:
		var vfx: WeaponVFX = vfx_scene.instantiate()
		vfx.texture = stats.muzzle_flash

		var vfx_length: float = SpriteHelpers.SpriteDetails.get_frame_rect(vfx).x
		vfx.position = proj_origin
		vfx.position.x += (vfx_length / 2)

		add_child(vfx)

## Start the firing animation based on what kind of firing we are doing.
func _start_firing_anim(was_charge_fire: bool = false) -> void:
	if anim_player.is_playing():
		return
	if not was_charge_fire:
		if stats.one_frame_per_fire:
			# If using one frame per fire, we know it is an animated sprite
			sprite.frame = ((sprite as AnimatedSprite2D).frame + 1) % (sprite as AnimatedSprite2D).sprite_frames.get_frame_count(sprite.animation)
			return
		if stats.override_anim_dur > 0:
			anim_player.speed_scale = 1.0 / stats.override_anim_dur
		else:
			anim_player.speed_scale = 1.0 / max(0.03, (stats.firing_duration + hitscan_delay))
		anim_player.speed_scale *= stats.anim_speed_mult
		if anim_player.has_animation("fire"): anim_player.play("fire")
	else:
		if stats.one_frame_per_chg_fire:
			# If using one frame per charge fire, we know it is an animated sprite
			sprite.frame = ((sprite as AnimatedSprite2D).frame + 1) % (sprite as AnimatedSprite2D).sprite_frames.get_frame_count(sprite.animation)
			return
		if stats.override_chg_anim_dur > 0   :
			anim_player.speed_scale = 1.0 / stats.override_chg_anim_dur
		else:
			anim_player.speed_scale = 1.0 / max(0.03, (stats.charge_firing_duration + hitscan_delay))
		anim_player.speed_scale *= stats.chg_anim_speed_mult
		if anim_player.has_animation("charge_fire"): anim_player.play("charge_fire")

## Applies a status effect to the source entity after firing.
func _apply_post_firing_effect(was_charge_fire: bool = false) -> void:
	var effect: StatusEffect = stats.post_firing_effect if not was_charge_fire else stats.post_chg_shot_effect
	if effect != null:
		source_entity.effect_receiver.handle_status_effect(effect)
#endregion

#region Reloading & Recharging
## Checks if we have enough ammo to execute a single firing. Calls for a reload if we don't.
func _get_has_needed_ammo_and_reload_if_not(was_charge_fire: bool = false) -> bool:
	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA and (source_entity is not DynamicEntity):
		push_error(source_entity.name + " is using a weapon with ammo type \"Stamina\" but is not a dynamic entity.")
		return false

	var result: bool = false
	var ammo_needed: int = 0

	if was_charge_fire:
		ammo_needed = stats.ammo_use_per_charge
	else:
		if stats.use_ammo_per_burst_proj:
			ammo_needed += int(stats.s_mods.get_stat("projectiles_per_fire"))
		else:
			ammo_needed = 1

	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
		var stamina_uses_left: int = int(floor(source_entity.stamina_component.stamina / (ammo_needed * stats.stamina_use_per_proj)))
		if stamina_uses_left > 0:
			result = true
	elif stats.ammo_type == ProjWeaponResource.ProjAmmoType.SELF:
		result = true
	else:
		if stats.ammo_in_mag >= ammo_needed:
			result = true
		if result == false:
			if not is_reloading:
				_attempt_reload()
				if stats.empty_mag_sound != "":
					AudioManager.play_sound(stats.empty_mag_sound, AudioManager.SoundType.SFX_GLOBAL)

	return result

## Takes away either the passed in amount from the appropriate ammo reserve.
func _consume_ammo(amount: int) -> void:
	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
		(source_entity as DynamicEntity).stamina_component.use_stamina(amount * stats.stamina_use_per_proj)
	elif stats.ammo_type == ProjWeaponResource.ProjAmmoType.SELF:
		source_entity.inv.remove_item(source_slot.index, 1)
	else:
		stats.ammo_in_mag -= amount
		_request_ammo_recharge()

	_update_ammo_ui()

## Based on the reload method, starts the timer(s) needed to track how long the reload will take.
func _attempt_reload() -> void:
	var any_ammo: bool = _get_more_reload_ammo(1, false) > 0
	if not any_ammo:
		return

	is_reloading = true

	var ammo_needed: int = int(stats.s_mods.get_stat("mag_size")) - stats.ammo_in_mag
	if ammo_needed > 0:
		source_entity.hands.been_holding_time = 0

	if stats.reload_type == "Single":
		is_reloading_single_and_has_since_released = false
		var single_reload_time: float = stats.s_mods.get_stat("single_proj_reload_time")
		var reloads_needed: int = int(ceil(float(ammo_needed) / stats.s_mods.get_stat("single_reload_quantity")))

		reload_timer.start(single_reload_time * reloads_needed)
		single_reload_timer.set_meta("reloads_left", reloads_needed)
		single_reload_timer.start(single_reload_time)
	else:
		if stats.mag_reload_sound != "": AudioManager.play_sound(stats.mag_reload_sound, AudioManager.SoundType.SFX_GLOBAL)
		reload_timer.start(stats.s_mods.get_stat("mag_reload_time"))

## Searches through the source entity's inventory for more ammo to fill the magazine. Can optionally be used to only check for ammo
## when told not to take from the inventory when found.
func _get_more_reload_ammo(max_amount_needed: int, take_from_inventory: bool = true) -> int:
	var ammount_collected: int = 0
	var inv_node: Inventory = source_entity.inv

	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.NONE:
		ammount_collected = max_amount_needed
	else:
		for i: int in range(inv_node.inv_size):
			var item: InvItemResource = inv_node.inv[i]
			if item != null and (item.stats is ProjAmmoResource) and (item.stats.ammo_type == stats.ammo_type):
				var amount_in_slot: int = item.quantity
				var amount_still_needed: int = max_amount_needed - ammount_collected
				var amount_to_take_from_slot: int = min(amount_still_needed, amount_in_slot)
				if take_from_inventory:
					inv_node.remove_item(i, amount_to_take_from_slot)
				ammount_collected += amount_to_take_from_slot

				if ammount_collected == max_amount_needed:
					break

	return ammount_collected

## When the main reload timer ends and we are in "Magazine" mode, reload the magazine.
func _on_reload_timer_timeout() -> void:
	if stats.reload_type != "Magazine":
		return

	var ammo_needed: int = int(stats.s_mods.get_stat("mag_size")) - stats.ammo_in_mag
	var ammo_available: int = _get_more_reload_ammo(ammo_needed)
	stats.ammo_in_mag += ammo_available
	_update_ammo_ui()
	is_reloading = false

## When the single projectile reload timer ends, try and grab a bullet and see if we need to start it up again.
func _on_single_reload_timer_timeout() -> void:
	var reloads_left: int = single_reload_timer.get_meta("reloads_left")
	var ammo_needed: int = stats.s_mods.get_stat("mag_size") - stats.ammo_in_mag
	var ammo_available: int = _get_more_reload_ammo(min(ammo_needed, stats.s_mods.get_stat("single_reload_quantity")))
	if ammo_available > 0:
		if stats.proj_reload_sound != "": AudioManager.play_sound(stats.proj_reload_sound, AudioManager.SoundType.SFX_GLOBAL)

		stats.ammo_in_mag = min(stats.s_mods.get_stat("mag_size"), stats.ammo_in_mag + ammo_available)
		_update_ammo_ui()
		if reloading_ui: reloading_ui.update_progress(stats.ammo_in_mag)

		if reloads_left > 1 and (stats.ammo_in_mag != stats.s_mods.get_stat("mag_size")):
			single_reload_timer.set_meta("reloads_left", reloads_left - 1)
			single_reload_timer.start(stats.s_mods.get_stat("single_proj_reload_time"))
			return

	is_reloading = false

## When we hav recently fired, we should not instantly keep recharging ammo, so we send a cooldown to the recharger.
func _notify_recharge_of_a_recent_firing() -> void:
	if stats.s_mods.get_stat("auto_ammo_interval") > 0:
		source_entity.inv.auto_decrementer.update_recharge_delay(str(stats.session_uid), stats.auto_ammo_delay)

## This is called (usually after firing) to request a new ammo recharge instance. It is also called when first entering if we
## aren't at max ammo already.
func _request_ammo_recharge() -> void:
	if stats.s_mods.get_stat("auto_ammo_interval") > 0:
		source_entity.inv.auto_decrementer.request_recharge(StringName(str(stats.session_uid)), stats)

## When an ammo recharge ends, if it matches our item id, update the ammo ui.
func _on_ammo_recharge_completed(item_id: StringName) -> void:
	if item_id != str(stats.session_uid):
		return
	else:
		_update_ammo_ui()

## Updates the ammo UI with the ammo in the magazine, assuming this is being used by a Player and the weapon uses
## consumable ammo.
func _update_ammo_ui() -> void:
	if ammo_ui != null and not stats.hide_ammo_ui:
		var count: int = -1
		if stats.ammo_type == ProjWeaponResource.ProjAmmoType.SELF:
			if source_slot.item == null:
				count = -1
			else:
				count = source_slot.item.quantity
		elif stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
			count = source_entity.stamina_component.stamina
		else:
			count = stats.ammo_in_mag
		ammo_ui.update_mag_ammo(count)
#endregion
