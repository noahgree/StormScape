@tool
@icon("res://Utilities/Debug/EditorIcons/projectile_weapon.png")
extends Weapon
class_name ProjectileWeapon
## New proj weapon script. WIP.

signal state_changed(new_state: WeaponState)

enum WeaponState { IDLE, WARMING_UP, FIRING, RELOADING, OVERHEATED }

@export var proj_origin: Vector2 = Vector2.ZERO: set = _set_proj_origin ## Where the projectile spawns from in local space of the weapon scene.
@export var casing_scene: PackedScene = preload("res://Entities/Items/Weapons/WeaponVFX/Casings/Casing.tscn")
@export var overheat_overlays: Array[TextureRect] = []

@onready var proj_origin_node: Marker2D = $ProjectileOrigin ## The point at which projectiles should spawn from.
@onready var casing_ejection_point: Marker2D = get_node_or_null("CasingEjectionPoint") ## The point from which casings should eject if need be.
@onready var reload_off_hand: EntityHandSprite = get_node_or_null("ReloadOffHand") ## The off hand only shown and animated during reloads.
@onready var reload_main_hand: EntityHandSprite = get_node_or_null("ReloadMainHand") ## The main hand only shown and animated during reloads.
@onready var firing_vfx: WeaponFiringVFX = get_node_or_null("FiringVFX") ## The vfx that spawns when firing.

var state: WeaponState = WeaponState.IDLE: set = set_state
var firing_handler: FiringHandler = FiringHandler.new()
var warmup_handler: WarmupHandler = WarmupHandler.new()
var reload_handler: ReloadHandler = ReloadHandler.new()
var overheat_handler: OverheatHandler = OverheatHandler.new()
var is_charging: bool = false ## When true, we are holding the trigger down and trying to charge up.
var current_hitscans: Array[Hitscan] = [] ## The currently spawned array of hitscans to get cleaned up when we unequip this weapon.
var mouse_scan_area_targets: Array[Node] = [] ## The array of potential targets found and passed to the proj when using the "Mouse Position" homing method.
var mouse_area: Area2D ## The area around the mouse that scans for targets when using the "Mouse Position" homing method
var overhead_ui: PlayerOverheadUI ## The UI showing the overhead stat changes (like reloading) in progress. Only applicable and non-null for players.
var preloaded_sounds: Array[StringName] = [] ## The sounds kept in memory while this weapon scene is alive that must be dereferenced upon exiting the tree.


#region Debug
func _set_proj_origin(new_proj_origin: Vector2) -> void:
	proj_origin = new_proj_origin
	if proj_origin_node: proj_origin_node.position = proj_origin
#endregion

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()

	firing_handler.initialize(self)
	warmup_handler.initialize(self)
	reload_handler.initialize(self)
	overheat_handler.initialize(self)

	if source_entity is Player:
		overhead_ui = source_entity.overhead_ui

		# Update the ammo UI when stamina changes
		if (stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA) and (not stats.hide_ammo_ui):
				source_entity.stamina_component.stamina_changed.connect(
					func(_new_stamina: float) -> void: _update_ammo_ui()
					)

	_setup_firing_vfx()
	_register_preloaded_sounds()

func _register_preloaded_sounds() -> void:
	preloaded_sounds = [stats.firing_sound, stats.charging_sound, stats.projectile_logic.splitting_sound]
	AudioPreloader.register_sounds_from_ids(preloaded_sounds)

func enable() -> void:
	# When re-enabling, see if we stil are in overheat penalty and need to show the visuals again
	if source_entity.inv.auto_decrementer.get_cooldown_source_title(stats.get_cooldown_id()) == "overheat_penalty":
		overheat_handler.start_max_overheat_visuals(true)

func disable() -> void:
	source_entity.hands.should_rotate = true
	if stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal_by_source(stats.charging_stat_effect.id, Globals.StatusEffectSourceType.FROM_SELF)
	is_charging = false

func enter() -> void:
	if stats.s_mods.get_stat("pullout_delay") > 0:
		pullout_delay_timer.start(stats.s_mods.get_stat("pullout_delay"))

	ensure_ammo_or_reload()
	_update_ammo_ui()
	reload_handler.request_ammo_recharge()
	_setup_mouse_area_scanner()

	# When entering, see if we stil are in overheat penalty and need to show the visuals again
	if source_entity.inv.auto_decrementer.get_cooldown_source_title(stats.get_cooldown_id()) == "overheat_penalty":
		overheat_handler.start_max_overheat_visuals(true)

func exit() -> void:
	set_process(false)
	super.exit()

	source_entity.hands.should_rotate = true
	reload_handler.do_post_reload_animation_cleanup()

	_clean_up_hitscans()

	if mouse_area:
		mouse_area.queue_free()

	if stats.charging_stat_effect != null:
		source_entity.effects.request_effect_removal_by_source(stats.charging_stat_effect.id, Globals.StatusEffectSourceType.FROM_SELF)

	source_entity.hands.smoke_particles.emitting = false
	source_entity.hands.smoke_particles.visible = false

func _exit_tree() -> void:
	AudioPreloader.unregister_sounds_from_ids(preloaded_sounds)

func set_state(new_state: WeaponState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(state)

func enable_mouse_area() -> void:
	if mouse_area:
		mouse_area.get_child(0).disabled = false

func disable_mouse_area() -> void:
	if mouse_area:
		mouse_area.get_child(0).disabled = true

## If we are set to do mouse position-based homing, we set up the mouse area and its signals and add it as a child.
func _setup_mouse_area_scanner() -> void:
	if stats.use_hitscan or stats.projectile_logic.homing_method != "Mouse Position":
		return

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

	Globals.world_root.add_child(mouse_area)

## Sets up the firing vfx's positioning and offset to work with y sorting.
func _setup_firing_vfx() -> void:
	if firing_vfx == null:
		return

	# Getting it to show above the projectiles in y-sort order
	firing_vfx.position = proj_origin + Vector2(0, 3)
	firing_vfx.offset = Vector2(0, -3)

	# By default it will be centered at the proj origin, but we want it to have its left side at that point
	firing_vfx.position.x += SpriteHelpers.SpriteDetails.get_frame_rect(firing_vfx, true).x / 2.0

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	reload_handler.update_reload_progress_ui()

	if stats.show_cursor_cooldown:
		_update_cursor_cooldown_ui()

	overheat_handler.update_overlays_and_overhead_ui()

func _physics_process(_delta: float) -> void:
	if mouse_area != null:
		mouse_area.global_position = CursorManager.get_cursor_mouse_position()

func _can_activate_at_all() -> bool:
	if state not in [WeaponState.IDLE, WeaponState.RELOADING]:
		return false
	if state == WeaponState.RELOADING:
		if (stats.reload_type == ProjWeaponResource.ReloadType.MAGAZINE) or stats.must_reload_fully:
			return false
	return true

func activate() -> void:
	if not _can_activate_at_all():
		return

	if stats.firing_mode == ProjWeaponResource.FiringType.SEMI_AUTO:
		_attempt_to_fire()

func hold_activate(delta: float) -> void:
	if not _can_activate_at_all():
		hold_time = 0
		return

	hold_time += delta

	match stats.firing_mode:
		ProjWeaponResource.FiringType.AUTO:
			_attempt_to_fire()
		ProjWeaponResource.FiringType.CHARGE:
			if (not is_charging) and (stats.charging_stat_effect != null):
				var effect: StatusEffect = stats.charging_stat_effect.duplicate()
				effect.mod_time = 100000000
				source_entity.effect_receiver.handle_status_effect(effect)
			is_charging = true

			if stats.auto_do_charge_use and hold_time >= stats.s_mods.get_stat("min_charge_time"):
				_attempt_to_fire()

func release_hold_activate() -> void:
	if not _can_activate_at_all():
		hold_time = 0
		return

	if stats.firing_mode == ProjWeaponResource.FiringType.CHARGE:
		if stats.charging_stat_effect != null:
			source_entity.effects.request_effect_removal_by_source(stats.charging_stat_effect.id, Globals.StatusEffectSourceType.FROM_SELF)
		is_charging = false

		if hold_time >=  stats.s_mods.get_stat("min_charge_time"):
			_attempt_to_fire()

func _attempt_to_fire() -> void:
	hold_time = 0
	start_firing_sequence()

func start_firing_sequence() -> void:
	# ---Check Can Fire---
	if not firing_handler.can_fire():
		set_state(WeaponState.IDLE)
		return

	# ---Cancel Current Reload---
	if state == WeaponState.RELOADING:
		reload_handler.cancel_reload()

	# ---Ammo Check---
	if not await ensure_ammo_or_reload():
		set_state(WeaponState.IDLE)
		return

	# ---Warmup Phase---
	if warmup_handler.needs_warmup():
		set_state(WeaponState.WARMING_UP)
		warmup_handler.start_warmup()
		await warmup_handler.warmup_finished

	# ---Firing Phase---
	set_state(WeaponState.FIRING)
	await firing_handler.start_firing()

	# ---Overheating Phase---
	if overheat_handler.is_overheated():
		set_state(WeaponState.OVERHEATED)
		await overheat_handler.overheat_emptied

	# ---Check Ammo Again---
	await ensure_ammo_or_reload()

	# ---Idling---
	set_state(WeaponState.IDLE)

## Called from the hands component when we press the reload key.
func reload() -> void:
	if state not in [WeaponState.RELOADING, WeaponState.FIRING, WeaponState.WARMING_UP]:
		set_state(WeaponState.RELOADING)
		reload_handler.attempt_reload()
		await reload_handler.reload_finished

func ensure_ammo_or_reload() -> bool:
	var has_needed_ammo: bool = false

	var ammo_needed: int = int(stats.s_mods.get_stat("projectiles_per_fire"))
	if not stats.use_ammo_per_burst_proj:
		ammo_needed = 1

	match stats.ammo_type:
		ProjWeaponResource.ProjAmmoType.STAMINA:
			var stamina_needed: float = ammo_needed * stats.stamina_use_per_proj
			has_needed_ammo = (source_entity.stamina_component.stamina >= stamina_needed)
		ProjWeaponResource.ProjAmmoType.SELF:
			has_needed_ammo = true
		_:
			has_needed_ammo = (stats.ammo_in_mag >= ammo_needed)

	if has_needed_ammo:
		return true

	await reload()
	return false

func update_mag_ammo(new_amount: int) -> void:
	stats.ammo_in_mag = new_amount
	_update_ammo_ui()

## Updates the ammo UI with the ammo in the magazine, assuming this is being used by a Player and the weapon uses
## consumable ammo.
func _update_ammo_ui() -> void:
	if ammo_ui == null or stats.hide_ammo_ui:
		return

	var count: int = -1
	match stats.ammo_type:
		ProjWeaponResource.ProjAmmoType.SELF:
			if source_slot.item == null:
				count = -1
			else:
				count = source_slot.item.quantity
		ProjWeaponResource.ProjAmmoType.STAMINA:
			count = source_entity.stamina_component.stamina
		_:
			count = stats.ammo_in_mag

	ammo_ui.update_mag_ammo(count)
	ammo_ui.calculate_inv_ammo()

## When hitscans have ended or we swap off the weapon, free the hitscan itself.
func _clean_up_hitscans() -> void:
	for hitscan: Variant in current_hitscans:
		if is_instance_valid(hitscan):
			hitscan.queue_free()
	current_hitscans.clear()

## Gets a current cooldown level from the auto decrementer based on the cooldown id.
func get_cooldown() -> float:
	return source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id())

## Adds a cooldown to the auto decrementer for the current cooldown id.
func add_cooldown(duration: float, title: String = "default") -> void:
	if duration <= 0:
		return
	source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), duration, title)

func _on_cooldown_ended(item_id: StringName, source_title: String) -> void:
	if item_id != str(stats.session_uid):
		return

	match source_title:
		"overheat_penalty":
			overheat_handler.end_max_overheat_visuals()

func _update_cursor_cooldown_ui() -> void:
	if not source_entity is Player:
		return

	var cooldown_remaining: float = get_cooldown()
	var original_cooldown: float = source_entity.inv.auto_decrementer.get_original_cooldown(stats.get_cooldown_id())
	var tint_progress: float = 100.0
	if cooldown_remaining > 0:
		tint_progress = (1 - (cooldown_remaining / original_cooldown)) * 100.0
	CursorManager.update_vertical_tint_progress(tint_progress)

## Spawns a simulated ejected casing to fall to the ground. Requires a Marker2D in the scene called
## "CasingEjectionPoint". Must be called by the animation player due to varying timing of when it should
## spawn per weapon.
func _eject_casing(per_used_ammo: bool = false) -> void:
	if not casing_ejection_point:
		return

	for i: int in range((stats.s_mods.get_stat("mag_size") - stats.ammo_in_mag) if per_used_ammo else 1):
		var casing: Node2D = casing_scene.instantiate()
		var casing_rand_offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1))
		casing.global_position = casing_ejection_point.global_position + casing_rand_offset
		casing.global_rotation = global_rotation

		Globals.world_root.add_child(casing)

		casing.sprite.texture = stats.casing_texture
		if stats.casing_tint != Color.WHITE:
			casing.sprite.modulate = stats.casing_tint

func reset_animation_state() -> void:
	anim_player.play("RESET")
