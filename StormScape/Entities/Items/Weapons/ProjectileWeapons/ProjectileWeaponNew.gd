extends Weapon
class_name ProjectileWeaponNew
## New proj weapon script. WIP.

signal state_changed(new_state: WeaponState)

enum WeaponState { IDLE, WARMING_UP, FIRING, RELOADING, CHARGING, OVERHEATED }

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

var state: WeaponState = WeaponState.IDLE: set = set_state
var firing_handler: FiringHandler = FiringHandler.new()
var warmup_handler: WarmupHandler = WarmupHandler.new()
#var charging_handler:
var reload_handler: ReloadHandler = ReloadHandler.new()
var overheat_handler: OverheatHandler = OverheatHandler.new()


func set_state(new_state: WeaponState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(state)

func run_firing_sequence() -> void:
	# ---Check Ammo---
	if not check_for_needed_ammo():
		set_state(WeaponState.RELOADING)
		await reload_handler.attempt_reload()
		return

	# ---Warmup Phase---
	if warmup_handler.needs_warmup():
		set_state(WeaponState.WARMING_UP)
	await warmup_handler.start_warmup()

	# ---Firing Phase---
	set_state(WeaponState.FIRING)
	await firing_handler.start_firing()

	# ---Check Ammo Again---
	if not check_for_needed_ammo():
		set_state(WeaponState.RELOADING)
		await reload_handler.attempt_reload()

	# ---Idling---
	set_state(WeaponState.IDLE)


func check_for_needed_ammo() -> bool:
	if stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA and not (source_entity is DynamicEntity):
		push_error(source_entity.name + " is using a weapon with ammo type 'STAMINA' but is not a dynamic entity.")
		return false

	var ammo_needed: int = int(stats.s_mods.get_stat("projectiles_per_fire"))
	if not stats.use_ammo_per_burst_proj:
		ammo_needed = 1

	match stats.ammo_type:
		ProjWeaponResource.ProjAmmoType.STAMINA:
			var stamina_needed: float = ammo_needed * stats.stamina_use_per_proj
			return (source_entity.stamina_component.stamina >= stamina_needed)
		ProjWeaponResource.ProjAmmoType.SELF:
			return true
		_:
			if stats.ammo_in_mag >= ammo_needed:
				return true
			return false
