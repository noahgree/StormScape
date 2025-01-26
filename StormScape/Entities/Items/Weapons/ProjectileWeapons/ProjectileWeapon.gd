@tool
@icon("res://Utilities/Debug/EditorIcons/projectile_weapon.png")
extends Weapon
class_name ProjectileWeapon
## Base class for all weapons that spawn any sort of projectile or hitscan or AOE.

@export var proj_origin: Vector2 = Vector2.ZERO: ## Where the projectile spawns from in local space of the weapon scene.
	set(new_origin):
		proj_origin = new_origin
		if proj_origin_node:
			proj_origin_node.position = proj_origin
@export var casing_scene: PackedScene = preload("res://Entities/Items/Weapons/WeaponVFX/Casings/Casing.tscn")
@export var overheat_overlays: Array[TextureRect] = []
@export var particle_emission_extents: Vector2:
	set(new_value):
		particle_emission_extents = new_value
		if debug_emission_box:
			_debug_update_particle_emission_box()
@export var particle_emission_origin: Vector2:
	set(new_value):
		particle_emission_origin = new_value
		if debug_emission_box:
			_debug_update_particle_emission_box()

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this projectile weapon.
@onready var proj_origin_node: Marker2D = $ProjectileOrigin ## The point at which projectiles should spawn from.
@onready var casing_ejection_point: Marker2D = get_node_or_null("CasingEjectionPoint") ## The point from which casings should eject if need be.
@onready var debug_emission_box: Polygon2D = get_node_or_null("DebugEmissionBox")
@onready var reload_off_hand: EntityHandSprite = get_node_or_null("ReloadOffHand") ## The off hand only shown and animated during reloads.
@onready var reload_main_hand: EntityHandSprite = get_node_or_null("ReloadMainHand") ## The main hand only shown and animated during reloads.
@onready var firing_vfx: WeaponFiringVFX = get_node_or_null("FiringVFX")

#region Local Vars
const MAX_ALLOTTED_CLUSTER_DELAY: float = 0.5 ## The max amount of time between each projectile
var firing_duration_timer: Timer = TimerHelpers.create_one_shot_timer(self) ## The timer tracking how long after we press fire before the proj spawns.
var reload_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_reload_timer_timeout) ## The timer tracking the delay between reload start and end.
var single_reload_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_single_reload_timer_timeout) ## The timer tracking the delay between single bullet reloads.
var single_reload_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_single_reload_delay_timer_timeout) ## The timer tracking the delay before starting the first single reload.
var hitscan_hands_freeze_timer: Timer = TimerHelpers.create_one_shot_timer(self, -1, _on_hitscan_hands_freeze_timer_timeout) ## The timer that tracks the brief moment after a semi-auto hitscan shot that we shouldn't be rotating.
var hold_just_released: bool = false ## Whether the mouse hold was just released.
var is_reloading: bool = false: ## Whether some reload method is currently in progress.
	set(new_value):
		is_reloading = new_value
		if is_reloading:
			if overhead_ui:
				overhead_ui.reload_bar.show()
		else:
			_do_post_reload_animation_cleanup()
			CursorManager.update_vertical_tint_progress(100.0)
			if overhead_ui:
				overhead_ui.reload_bar.hide()
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
var overhead_ui: PlayerOverheadUI ## The UI showing the overhead stat changes (like reloading) in progress. Only applicable and non-null for players.
var just_hit_max_overheat: bool = false ## When true, we reached max overheat after the most recent firing and should not overwrite the overheat penalty cooldown with the default firing cooldown.
var is_tweening_overheat_overlays: bool = false ## Whether the post-overheat penalty tween is lowering the opacity of the overlays.
var firing_in_progress: bool = false ## When true, we are waiting on burst delays and cluster delays that are still in progress.
var bursting_in_progress: bool = false ## A second conditional for determining if firing is still ongoing due to bursting potentially taking more time than the barrage/cluster logic.
#endregion


#region Debug
func _debug_update_particle_emission_box() -> void:
	if debug_emission_box == null or not Engine.is_editor_hint():
		return
	var top_left: Vector2 = particle_emission_origin - particle_emission_extents
	var bottom_right: Vector2 = particle_emission_origin + particle_emission_extents
	var points: Array[Vector2] = [top_left, Vector2(bottom_right.x, top_left.y), bottom_right, Vector2(top_left.x, bottom_right.y)]
	debug_emission_box.polygon = points
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
		stats.original_status_effects = stats.effect_source.status_effects.duplicate()
		_setup_mod_cache()

## Sets up the base values for the stat mod cache so that weapon mods can be added and managed properly.
func _setup_mod_cache() -> void:
	var normal_moddable_stats: Dictionary[StringName, float] = {
		&"fire_cooldown" : stats.fire_cooldown,
		&"min_charge_time" : stats.min_charge_time,
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

	stats.s_mods.add_moddable_stats(normal_moddable_stats)
	stats.cache_is_setup = true

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	super._ready()

	if source_entity is Player:
		overhead_ui = source_entity.overhead_ui
		source_entity.inv.auto_decrementer.overheat_empty.connect(_on_overheat_emptied)

	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
		if source_entity is DynamicEntity and not stats.hide_ammo_ui:
			source_entity.stamina_component.stamina_changed.connect(_update_ammo_ui)

	if reload_off_hand: reload_off_hand.hide()
	if reload_main_hand: reload_main_hand.hide()

	source_entity.inv.auto_decrementer.cooldown_ended.connect(_on_cooldown_timeout)
	source_entity.inv.auto_decrementer.recharge_completed.connect(_on_ammo_recharge_completed)

	anim_player.animation_finished.connect(_on_any_animation_finished)
	_setup_firing_vfx()

func disable() -> void:
	source_entity.facing_component.should_rotate = true
	source_entity.hands.should_rotate = true
	is_holding_hitscan = false
	is_reloading_single_and_has_since_released = true

	if stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal(stats.charging_stat_effect.effect_name)
	is_charging = false

func enable() -> void:
	if overhead_ui:
		if source_entity.inv.auto_decrementer.get_cooldown_source_title(stats.get_cooldown_id()) == "overheat_penalty":
			_do_weapon_overheat_visuals(true)

func enter() -> void:
	if stats.s_mods.base_values.is_empty():
		_setup_mod_cache()

	# The first time a weapon resource is loaded it has a default ammo_in_mag value of -1, this takes care of setting it to mag_size
	if (stats.ammo_in_mag == -1) and (stats.ammo_type != ProjWeaponResource.ProjAmmoType.STAMINA):
		stats.ammo_in_mag = stats.s_mods.get_stat("mag_size")
	else:
		_get_has_needed_ammo_and_reload_if_not()
	_update_ammo_ui()

	# Checking to see if we are out of ammo and should reload upon equipping
	if stats.ammo_type != ProjWeaponResource.ProjAmmoType.SELF and stats.ammo_type != ProjWeaponResource.ProjAmmoType.STAMINA:
		if stats.ammo_in_mag < stats.s_mods.get_stat("mag_size"):
			_request_ammo_recharge()

	# Updating the overheating visuals and overlays if needed
	if overhead_ui:
		if source_entity.inv.auto_decrementer.get_cooldown_source_title(stats.get_cooldown_id()) == "overheat_penalty":
			overhead_ui.update_visuals_for_max_overheat()
			overhead_ui.overheat_bar.show()
			for overlay: TextureRect in overheat_overlays:
				overlay.self_modulate.a = source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid))
			_do_weapon_overheat_visuals(true)
		elif source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid)) > 0:
			overhead_ui.overheat_bar.show()
			for overlay: TextureRect in overheat_overlays:
				overlay.self_modulate.a = source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid)) / 2.0

	_check_if_needs_mouse_area_scanner()

	if stats.weapon_mods_need_to_be_readded_after_save:
		for weapon_mod: WeaponMod in stats.current_mods.values():
			weapon_mod_manager.handle_weapon_mod(weapon_mod)
		stats.weapon_mods_need_to_be_readded_after_save = false

func exit() -> void:
	set_process(false)

	super.exit()

	source_entity.facing_component.should_rotate = true
	source_entity.hands.should_rotate = true
	_do_post_reload_animation_cleanup()
	_clean_up_hitscans()
	if mouse_area: mouse_area.queue_free()

	if stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal(stats.charging_stat_effect.effect_name)

	source_entity.hands.smoke_particles.emitting = false
	source_entity.hands.smoke_particles.visible = false

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
		mouse_area.global_position = CursorManager.get_cursor_mouse_position()
		GlobalData.world_root.add_child(mouse_area)

func _enable_mouse_area() -> void:
	if mouse_area: mouse_area.get_child(0).disabled = false

func _disable_mouse_area() -> void:
	if mouse_area: mouse_area.get_child(0).disabled = true

## Every frame we decrease the warmup and the bloom levels based on their decrease curves.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not overhead_ui:
		return

	if is_reloading and not stats.hide_reload_ui:
		var reload_progress: int = int((1 - (reload_timer.time_left / reload_timer.wait_time)) * 100)
		if not single_reload_delay_timer.is_stopped():
			if not stats.show_cursor_cooldown: CursorManager.update_vertical_tint_progress(0.0)
			overhead_ui.update_reload_progress(0)
		else:
			if not stats.show_cursor_cooldown: CursorManager.update_vertical_tint_progress(reload_progress)
			overhead_ui.update_reload_progress(reload_progress)
	if stats.show_cursor_cooldown:
		var cooldown_remaining: float = source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id())
		var original_cooldown: float = source_entity.inv.auto_decrementer.get_original_cooldown(stats.get_cooldown_id())
		if cooldown_remaining > 0:
			CursorManager.update_vertical_tint_progress((1 - (cooldown_remaining / original_cooldown)) * 100.0)
		else:
			CursorManager.update_vertical_tint_progress(100.0)

	var current_overheat: float = source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid))
	if current_overheat > 0:
		if source_entity.inv.auto_decrementer.get_cooldown_source_title(stats.get_cooldown_id()) != "overheat_penalty":
			overhead_ui.update_overheat_progress(int(current_overheat * 100.0))
			if not is_tweening_overheat_overlays:
				for overlay: TextureRect in overheat_overlays:
					overlay.self_modulate.a = current_overheat / 2.0
		else:
			overhead_ui.update_overheat_progress(100)

func _physics_process(_delta: float) -> void:
	if mouse_area != null:
		mouse_area.global_position = CursorManager.get_cursor_mouse_position()
#endregion

#region Called From HandsComponent
## Called from the hands component when the mouse is clicked.
func activate() -> void:
	if not pullout_delay_timer.is_stopped() or not firing_duration_timer.is_stopped() or firing_in_progress or bursting_in_progress:
		return
	if is_reloading and stats.reload_type == "Magazine":
		return

	is_reloading_single_and_has_since_released = true
	if stats.firing_mode == "Semi Auto":
		_fire()

## Called from the hands component when the mouse is held down. Includes how long it has been held down so far.
func hold_activate(_hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not firing_duration_timer.is_stopped() or firing_in_progress or bursting_in_progress:
		source_entity.hands.been_holding_time = 0
		return
	if is_reloading and stats.reload_type == "Magazine":
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

	if not pullout_delay_timer.is_stopped() or (is_reloading and stats.reload_type == "Magazine") or firing_in_progress or bursting_in_progress:
		source_entity.hands.been_holding_time = 0
		return

	is_reloading_single_and_has_since_released = true

	if stats.firing_mode == "Charge":
		if stats.charging_stat_effect != null:
			source_entity.effects.request_effect_removal(stats.charging_stat_effect.effect_name)
		if hold_time > 0:
			_charge_fire(hold_time)
		is_charging = false

	hold_just_released = true

## Called from the hands component when we press the reload key.
func reload() -> void:
	if stats.ammo_type not in [ProjWeaponResource.ProjAmmoType.STAMINA, ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.CHARGES]:
		if pullout_delay_timer.is_stopped() and not is_reloading:
			if (stats.ammo_in_mag < stats.s_mods.get_stat("mag_size")):
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
	if not _get_has_needed_ammo_and_reload_if_not():
		is_holding_hitscan = false
		return

	if is_reloading:
		single_reload_timer.stop()
		single_reload_delay_timer.stop()
		is_reloading = false
	if "reload" in anim_player.current_animation:
		_do_post_reload_animation_cleanup()

	var warmup_firing_delay: float = _get_warmup_firing_delay()
	if warmup_firing_delay > 0:
		_handle_adding_cooldown(warmup_firing_delay, "warmup")
		while _get_cooldown() > 0: # Signal fires for all ending cooldowns, so we loop until ours has ended
			await source_entity.inv.auto_decrementer.cooldown_ended
			if is_reloading: # If we trigger a reload while waiting for this warmup delay it will cause anim problems
				return

		if hold_just_released:
			hold_just_released = false
			return

	firing_duration_timer.start(max(0.05, stats.firing_duration))
	_start_firing_anim()
	await firing_duration_timer.timeout

	_set_up_hitscan()
	_handle_warmup_increase() # We only do this for regular firing, not charge shots
	_start_firing_sequence()

	if stats.use_hitscan and stats.allow_hitscan_holding and stats.firing_mode == "Auto" and not is_holding_hitscan:
		is_holding_hitscan = true

## Check if we can do a charge firing, and if we can, start it.
func _charge_fire(hold_time: float) -> void:
	if not _get_has_needed_ammo_and_reload_if_not():
		source_entity.hands.been_holding_time = 0
		return

	if (hold_time >= stats.s_mods.get_stat("min_charge_time")) and _get_cooldown() == 0:
		firing_duration_timer.start(max(0.05, stats.firing_duration))
		_start_firing_anim()
		await firing_duration_timer.timeout

		_set_up_hitscan()
		_start_firing_sequence()

## Set up the delay we will use if we have a non-holding or charged hitscan. This basically increases the shot duration.
func _set_up_hitscan() -> void:
	if not stats.use_hitscan:
		hitscan_delay = 0
	else:
		if not stats.allow_hitscan_holding or stats.firing_mode == "Charge":
			hitscan_delay = stats.s_mods.get_stat("hitscan_duration")
		else:
			hitscan_delay = 0

## When hitscans have ended or we swap off the weapon, free the hitscan itself.
func _clean_up_hitscans() -> void:
	for hitscan: Variant in current_hitscans:
		if is_instance_valid(hitscan):
			hitscan.queue_free()
	current_hitscans.clear()

## When the timer that runs when we shouldn't follow the mouse (because of an active hitscan) ends, allow mouse following again.
func _on_hitscan_hands_freeze_timer_timeout() -> void:
	source_entity.hands.should_rotate = true
#endregion

#region Projectile Spawning
## Applies the initial logic that occurs at the start of each firing sequence, whether it be a charge shot or not.
func _start_firing_sequence() -> void:
	firing_in_progress = true

	if stats.s_mods.get_stat("projectiles_per_fire") > 1 and not is_holding_hitscan:
		if not stats.add_bloom_per_burst_shot: _handle_bloom_increase()
	if not stats.add_overheat_per_burst_shot: _handle_overheat_increase()

	_apply_ammo_consumption()

## Calls to consume ammo based on how many shots we performed.
func _apply_ammo_consumption() -> void:
	var shot_count: int = int(stats.s_mods.get_stat("projectiles_per_fire"))
	if stats.dont_consume_ammo:
		_handle_per_shot_delay_and_bloom(shot_count, (not is_holding_hitscan))
		return

	if stats.use_ammo_per_burst_proj:
		for i: int in range(shot_count):
			_consume_ammo(1)
	else:
		_consume_ammo(1)

	_handle_per_shot_delay_and_bloom(shot_count, (not is_holding_hitscan))

## Calls to increase the bloom and awaits burst bullet delays if we have them. Can be told not to spawn afterwards as well.
func _handle_per_shot_delay_and_bloom(shot_count: int, proceed_to_spawn: bool = true) -> void:
	bursting_in_progress = true
	for i: int in range(shot_count):
		if stats.add_bloom_per_burst_shot or (stats.s_mods.get_stat("projectiles_per_fire") == 1):
			_handle_bloom_increase()
		if stats.add_overheat_per_burst_shot or (stats.s_mods.get_stat("projectiles_per_fire") == 1):
			_handle_overheat_increase()

		if proceed_to_spawn:
			_apply_barrage_logic()

			if i != (shot_count - 1):
				await get_tree().create_timer(max(0.03, stats.burst_bullet_delay), false, true, false).timeout
				if is_reloading: # We could potentially start a reload during this delay and need to break out of the burst loop
					break

	bursting_in_progress = false
	if not firing_in_progress: # If it is still in progress (meaning we are likely still barraging), we let it handle it after
		_do_post_fire_cooldown()
		_start_post_fire_anim()
		_start_post_fire_fx()
		_notify_recharge_of_a_recent_firing()

## Applies barrage logic to potentially spawn multiple projectiles at a specific angle apart.
func _apply_barrage_logic() -> void:
	_do_firing_fx() # Do these two methods before potential cluster delays
	_apply_firing_effect_to_entity()

	var effect_src: EffectSource = stats.effect_source

	var angular_spread_radians: float = deg_to_rad(stats.s_mods.get_stat("angular_spread"))
	var close_to_360_adjustment: int = 0 if stats.s_mods.get_stat("angular_spread") > 310 else 1
	var spread_segment_width: float = angular_spread_radians / (stats.s_mods.get_stat("barrage_count") - close_to_360_adjustment)

	var multishot_id: int = UIDHelper.generate_multishot_uid()

	for i: int in range(stats.barrage_count):
		var start_rotation: float = global_rotation - (angular_spread_radians / 2.0)
		if not stats.use_hitscan:
			var rotation_adjustment: float = start_rotation + (i * spread_segment_width)
			if stats.do_cluster_barrage:
				rotation_adjustment = start_rotation + randf_range(0, angular_spread_radians)

			var proj: Projectile = Projectile.create(stats, source_entity, proj_origin_node.global_position, global_rotation)
			proj.rotation = rotation_adjustment if stats.s_mods.get_stat("barrage_count") > 1 else proj.rotation
			proj.starting_proj_height = -(source_entity.hands.position.y + proj_origin.y + source_entity.hands.main_hand.position.y + source_entity.hands.hands_anchor.position.y) / 2
			proj.multishot_id = multishot_id

			# Handle the mouse-position homing logic if needed
			if stats.projectile_logic.homing_method == "Mouse Position":
				mouse_scan_area_targets.clear()
				_enable_mouse_area()
				var tree: SceneTree = get_tree()
				for j: int in range(2): await tree.physics_frame
				proj.mouse_scan_targets = mouse_scan_area_targets
				call_deferred("_disable_mouse_area")

			_spawn_projectile(proj)

			if stats.barrage_proj_delay > 0:
				await get_tree().create_timer(max(0.01, stats.barrage_proj_delay), false, false, false).timeout
		else:
			var hitscan_scene: PackedScene = stats.hitscan_logic.hitscan_scn

			var rotation_adjustment: float = -angular_spread_radians / 2 + (i * spread_segment_width)
			if stats.do_cluster_barrage:
				rotation_adjustment = randf() * spread_segment_width

			var hitscan: Hitscan = Hitscan.create(hitscan_scene, effect_src, self, source_entity, proj_origin_node.global_position, rotation_adjustment if stats.s_mods.get_stat("barrage_count") > 1 else 0.0, stats.firing_mode == "Charge")
			_spawn_hitscan(hitscan)

	firing_in_progress = false
	if not bursting_in_progress:  # If it is still in progress, we let it handle it after
		_do_post_fire_cooldown()
		_start_post_fire_anim()
		_start_post_fire_fx()
		_notify_recharge_of_a_recent_firing()

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
		source_entity.hands.should_rotate = false
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
func _handle_bloom_increase() -> void:
	if stats.s_mods.get_stat("max_bloom") > 0:
		var current_bloom: float = source_entity.inv.auto_decrementer.get_bloom(str(stats.session_uid))
		var sampled_point: float = stats.bloom_increase_rate.sample_baked(current_bloom)
		var increase_amount: float = max(0.01, sampled_point * stats.s_mods.get_stat("bloom_increase_rate_multiplier"))
		source_entity.inv.auto_decrementer.add_bloom(
			StringName(str(stats.session_uid)),
			min(1, (increase_amount)),
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
func _handle_adding_cooldown(duration: float, title: String = "default") -> void:
	if duration > 0:
		source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), duration, title)

## Gets a current cooldown level from the auto decrementer based on the cooldown id.
func _get_cooldown() -> float:
	return source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id())

## When the cooldown manager from the hands component fires a signal with the matching item id, process the aftermath.
func _on_cooldown_timeout(item_id: StringName, cooldown_source_title: String) -> void:
	if item_id != stats.get_cooldown_id():
		return

	if stats.firing_mode == "Charge":
		source_entity.hands.been_holding_time = 0

	if cooldown_source_title == "overheat_penalty": # Handling removing overheat visuals
		just_hit_max_overheat = false
		overhead_ui.update_visuals_for_max_overheat(true)
		source_entity.hands.smoke_particles.emitting = false

		var current_overheat: float = source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid))
		if current_overheat == 0:
			overhead_ui.overheat_bar.hide()

		if not overheat_overlays.is_empty():
			is_tweening_overheat_overlays = true
			var tween: Tween = create_tween().parallel()
			for overlay: TextureRect in overheat_overlays:
				tween.tween_property(overlay, "self_modulate:a", current_overheat, 0.15)
				tween.tween_method(func(new_value: Color) -> void: CursorManager.change_cursor_tint(new_value), CursorManager.get_cursor_tint(), Color.WHITE, 0.15)
				tween.chain().tween_callback(func() -> void: is_tweening_overheat_overlays = false)
		if anim_player.current_animation == "overheat":
			anim_player.stop()
			anim_player.play("RESET")
			anim_player.stop()

	if is_holding_hitscan:
		_fire()
		_handle_adding_cooldown(stats.s_mods.get_stat("fire_cooldown") + hitscan_delay, cooldown_source_title)
	else:
		_clean_up_hitscans()

## Starts the cooldown that happens after a firing sequence has ended, given that we aren't holding a hitscan.
func _do_post_fire_cooldown() -> void:
	if is_holding_hitscan: # There is different logic for the held hitscans when it comes to cooldown
		return
	if just_hit_max_overheat:
		return

	var total_cooldown_afterwards: float = stats.s_mods.get_stat("fire_cooldown") + hitscan_delay
	_handle_adding_cooldown(total_cooldown_afterwards)

## Increases current overheat level via sampling the increase curve using the current overheat.
func _handle_overheat_increase() -> void:
	if stats.s_mods.get_stat("overheat_penalty") > 0:
		var current_overheat: float = source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid))
		var sampled_point: float = stats.overheat_inc_rate.sample_baked(current_overheat)
		var increase_amount: float = max(0.005, sampled_point * stats.s_mods.get_stat("overheat_increase_rate_multiplier"))
		source_entity.inv.auto_decrementer.add_overheat(
			StringName(str(stats.session_uid)),
			min(1, (increase_amount)),
			stats.overheat_dec_rate,
			stats.overheat_dec_delay)

		overhead_ui.overheat_bar.show()

		if source_entity.inv.auto_decrementer.get_overheat(str(stats.session_uid)) >= 1:
			_handle_max_overheat_reached()

## When we reach max overheat, add a cooldown of some kind.
func _handle_max_overheat_reached() -> void:
	just_hit_max_overheat = true
	_handle_adding_cooldown(stats.s_mods.get_stat("overheat_penalty"), "overheat_penalty")
	if stats.overheated_sound != "": AudioManager.play_sound(stats.overheated_sound, AudioManager.SoundType.SFX_GLOBAL)
	overhead_ui.update_visuals_for_max_overheat()
	_do_weapon_overheat_visuals(false)

## Setup and start the overheating visuals.
func _do_weapon_overheat_visuals(just_equipped: bool) -> void:
	for overlay: TextureRect in overheat_overlays:
		overlay.self_modulate.a = 1.0

	CursorManager.change_cursor_tint(Color.ORANGE_RED)

	var smoke_particles: CPUParticles2D = source_entity.hands.smoke_particles
	smoke_particles.visible = true
	smoke_particles.emission_rect_extents = particle_emission_extents
	smoke_particles.position = particle_emission_origin + source_entity.hands.main_hand.position
	smoke_particles.emitting = true

	if anim_player.has_animation("overheat"):
		if just_equipped: # Don't want to play a one-off animation upon re-entering, only resume looping ones
			if not anim_player.get_animation("overheat").loop_mode > 0: # 0 is the enum value for no looping
				return
		anim_player.speed_scale = 1.0 / stats.overheat_anim_dur
		anim_player.play("overheat")

## When we receive a signal that any overheat has ended, if it matches this weapon, we potentially take action.
func _on_overheat_emptied(item_id: StringName) -> void:
	if item_id != str(stats.session_uid):
		return

	if source_entity.inv.auto_decrementer.get_cooldown_source_title(stats.get_cooldown_id()) != "overheat_penalty":
		overhead_ui.overheat_bar.hide()
#endregion

#region FX & Animations
## Sets up the firing vfx's positioning and offset to work with y sorting.
func _setup_firing_vfx() -> void:
	if not firing_vfx:
		return

	firing_vfx.position = proj_origin + Vector2(0, 3)
	firing_vfx.offset = Vector2(0, -3)
	if firing_vfx.sprite_frames:
		firing_vfx.position.x += SpriteHelpers.SpriteDetails.get_frame_rect(firing_vfx, true).x / 2.0
	else:
		firing_vfx.position.x += 8

## Start the sounds and vfx that should play when firing.
func _do_firing_fx() -> void:
	if stats.firing_cam_fx:
		stats.firing_cam_fx.activate_all()

	if stats.firing_sound != "":
		AudioManager.play_sound(stats.firing_sound, AudioManager.SoundType.SFX_2D, global_position)

	if firing_vfx:
		firing_vfx.start()

## Spawns a simulated ejected casing to fall to the ground. Requires a Marker2D in the scene called "CasingEjectionPoint".
## Must be called by the animation player due to varying timing of when it should spawn per weapon.
func _eject_casing() -> void:
	if casing_ejection_point:
		var casing: Node2D = casing_scene.instantiate()
		casing.global_position = casing_ejection_point.global_position
		casing.global_rotation = global_rotation
		GlobalData.world_root.add_child(casing)
		casing.sprite.texture = stats.casing_texture
		if stats.casing_tint != Color.WHITE:
			casing.sprite.modulate = stats.casing_tint

## Start the firing animation.
func _start_firing_anim() -> void:
	if anim_player.is_playing():
		push_warning(source_entity.name + " has a " + stats.name + " that was still playing the \"" + anim_player.current_animation + "\" animation upon the start of the firing animation. This will result in skipped animations.")
		return

	if stats.one_frame_per_fire:
		# If using one frame per fire, we know it is an animated sprite
		sprite.frame = ((sprite as AnimatedSprite2D).frame + 1) % (sprite as AnimatedSprite2D).sprite_frames.get_frame_count(sprite.animation)

	if stats.override_anim_dur > 0:
		anim_player.speed_scale = 1.0 / max(0.03, max(stats.firing_duration - 0.02, stats.override_anim_dur)) # The 0.02 is a buffer since animations aren't as precise in timing
	else:
		anim_player.speed_scale = 1.0 / max(0.03, stats.firing_duration - 0.02) # The 0.02 is a buffer since animations aren't as precise in timing

	anim_player.speed_scale *= stats.anim_speed_mult

	if anim_player.has_animation("fire"): anim_player.play("fire")

## Starts the post-firing animation if we have one.
func _start_post_fire_anim() -> void:
	if not anim_player.has_animation("post_fire"):
		_get_has_needed_ammo_and_reload_if_not()
		return
	elif anim_player.is_playing():
		await anim_player.animation_finished

	var adjusted_post_fire_anim_delay: float = max(0.05, stats.post_fire_anim_delay) if stats.post_fire_anim_delay > 0 else 0
	var available_time: float = max(0.03, stats.s_mods.get_stat("fire_cooldown") - adjusted_post_fire_anim_delay)
	var anim_duration: float = stats.post_fire_anim_dur if stats.post_fire_anim_dur > 0 else available_time

	anim_duration = min(anim_duration, available_time)
	anim_player.speed_scale = 1.0 / (anim_duration - 0.01) # The 0.01 is a buffer since animations aren't as precise in timing

	if adjusted_post_fire_anim_delay > 0:
		await get_tree().create_timer(adjusted_post_fire_anim_delay).timeout
		if anim_player.is_playing(): # Can happen if we start a reload during this delay
			return

	anim_player.play("post_fire")

## Starts the post-firing sound and vfx if we have one. Good for things like the cocking of a shotgun barrel after firing.
func _start_post_fire_fx() -> void:
	if stats.post_fire_sound == "":
		return

	var adjusted_post_fire_sound_delay: float = min(stats.s_mods.get_stat("fire_cooldown") - 0.05, stats.post_fire_sound_delay) if stats.post_fire_sound_delay > 0 else 0
	if adjusted_post_fire_sound_delay > 0.05:
		await get_tree().create_timer(adjusted_post_fire_sound_delay).timeout

	AudioManager.play_sound(stats.post_fire_sound, AudioManager.SoundType.SFX_2D, global_position)

## Applies a status effect to the source entity after firing.
func _apply_firing_effect_to_entity() -> void:
	if stats.post_firing_effect != null:
		source_entity.effect_receiver.handle_status_effect(stats.post_firing_effect)

## Checks if we need ammo after the post-firing animation has ended.
func _on_any_animation_finished(anim_name: StringName) -> void:
	if anim_name == "post_fire":
		_get_has_needed_ammo_and_reload_if_not()
#endregion

#region Reloading & Recharging
## Checks if we have enough ammo to execute a single firing. Calls for a reload if we don't.
func _get_has_needed_ammo_and_reload_if_not() -> bool:
	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA and (source_entity is not DynamicEntity):
		push_error(source_entity.name + " is using a weapon with ammo type \"Stamina\" but is not a dynamic entity.")
		return false

	var result: bool = false
	var ammo_needed: int = 0

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
	source_entity.hands.been_holding_time = 0

	if stats.reload_type == "Single":
		is_reloading_single_and_has_since_released = false

		var start_of_single_reload_delay: float = stats.single_proj_reload_delay
		if start_of_single_reload_delay > 0:
			single_reload_delay_timer.start(max(0.05, start_of_single_reload_delay))
			_start_reload_anim("before_single_reload")
		else:
			_on_single_reload_delay_timer_timeout() # Calling immediately if there is no delay needed
	else:
		if stats.mag_reload_sound != "": AudioManager.play_sound(stats.mag_reload_sound, AudioManager.SoundType.SFX_GLOBAL)
		reload_timer.start(stats.s_mods.get_stat("mag_reload_time"))
		_start_reload_anim("mag_reload")

## Checks for and starts the reload animation after hiding the player's off hand sprite from the hands component.
func _start_reload_anim(anim_name: String) -> void:
	if anim_name == "final_single_reload" and not anim_player.has_animation("final_single_reload"):
		anim_name = "single_reload"
	if not anim_player.has_animation(anim_name):
		return

	if anim_player.current_animation == "overheat":
		anim_player.stop()
		anim_player.play("RESET")
		anim_player.stop()

	source_entity.hands.off_hand_sprite.self_modulate.a = 0.0

	if anim_name == "before_single_reload":
		var dur: float = single_reload_delay_timer.wait_time if stats.before_single_reload_anim_dur <= 0 else (min(stats.single_proj_reload_delay, stats.before_single_reload_anim_dur))
		anim_player.speed_scale = 1.0 / (dur - 0.025) # 0.025 is a buffer to prevent overlap
	elif anim_name in ["single_reload", "final_single_reload"]:
		var dur: float = stats.s_mods.get_stat("single_proj_reload_time") if stats.reload_anim_dur <= 0 else (min(stats.single_proj_reload_time, stats.reload_anim_dur))
		anim_player.speed_scale = 1.0 / (dur - 0.025)
	elif anim_name == "mag_reload":
		var dur: float = reload_timer.wait_time if stats.reload_anim_dur <= 0 else (min(stats.mag_reload_time, stats.reload_anim_dur))
		anim_player.speed_scale = 1.0 / (dur - 0.025)

	anim_player.play(anim_name)

## Reshows the hand component's off hand and hides the local reload hand. Then it plays the RESET animation for one frame.
func _do_post_reload_animation_cleanup() -> void:
	source_entity.hands.off_hand_sprite.self_modulate.a = 1.0
	if reload_off_hand: reload_off_hand.hide()
	if reload_main_hand: reload_main_hand.hide()
	anim_player.stop()
	anim_player.play("RESET")
	anim_player.stop()

## Searches through the source entity's inventory for more ammo to fill the magazine.
## Can optionally be used to only check for ammo when told not to take from the inventory when found.
func _get_more_reload_ammo(max_amount_needed: int, take_from_inventory: bool = true) -> int:
	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.NONE:
		return max_amount_needed
	else:
		return source_entity.inv.get_more_ammo(max_amount_needed, take_from_inventory, stats.ammo_type)

## When the main reload timer ends and we are in "Magazine" mode, reload the magazine.
func _on_reload_timer_timeout() -> void:
	if stats.reload_type != "Magazine":
		return

	var ammo_needed: int = int(stats.s_mods.get_stat("mag_size")) - stats.ammo_in_mag
	var ammo_available: int = _get_more_reload_ammo(ammo_needed)
	stats.ammo_in_mag += ammo_available
	_update_ammo_ui()
	is_reloading = false

## When the start of a single reload process delay ends, begin the actual reloading timer based on ammo needed.
func _on_single_reload_delay_timer_timeout() -> void:
	var ammo_needed: int = stats.s_mods.get_stat("mag_size") - stats.ammo_in_mag
	var single_reload_time: float = stats.s_mods.get_stat("single_proj_reload_time")
	var reloads_needed: int = int(ceil(float(ammo_needed) / stats.s_mods.get_stat("single_reload_quantity")))

	reload_timer.start(single_reload_time * reloads_needed)
	single_reload_timer.set_meta("reloads_left", reloads_needed)
	single_reload_timer.start(single_reload_time)
	_start_reload_anim("final_single_reload" if reloads_needed == 1 else "single_reload")

## When the single projectile reload timer ends, try and grab a bullet and see if we need to start it up again.
func _on_single_reload_timer_timeout() -> void:
	var mag_size: int = stats.s_mods.get_stat("mag_size")
	var reloads_left: int = single_reload_timer.get_meta("reloads_left")
	var ammo_needed: int = mag_size - stats.ammo_in_mag
	var ammo_available: int = _get_more_reload_ammo(min(ammo_needed, stats.s_mods.get_stat("single_reload_quantity")))
	if ammo_available > 0:
		if stats.proj_reload_sound != "": AudioManager.play_sound(stats.proj_reload_sound, AudioManager.SoundType.SFX_GLOBAL)

		stats.ammo_in_mag = min(mag_size, stats.ammo_in_mag + ammo_available)
		_update_ammo_ui()

		if reloads_left > 1 and (stats.ammo_in_mag != mag_size):
			single_reload_timer.set_meta("reloads_left", reloads_left - 1)
			single_reload_timer.start(stats.s_mods.get_stat("single_proj_reload_time"))
			_start_reload_anim("final_single_reload" if reloads_left == 2 else "single_reload")
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
