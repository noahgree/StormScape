extends Node
class_name WeaponModManager
## The manager attached to each weapon that controls all weapon mod logic.

@export_subgroup("Debug")
@export var print_effect_updates: bool = false ## Whether to print when this weapon has mods added and removed. Printing the individual stat changes is decided by the cache resource itself. This only toggles the adding & removing of mod names as well as status effect changes.

var source_entity: PhysicsBody2D
const MAX_WEAPON_MODS: int = 3 ## The max amount of mods any weapon can have.


## Checks if the mod can be attached to the weapon.
static func check_mod_compatibility(weapon_stats: WeaponResource, weapon_mod: WeaponMod) -> bool:
	if weapon_mod.id in weapon_stats.blocked_mods:
		return false
	if weapon_stats is MeleeWeaponResource and weapon_stats.melee_weapon_type not in weapon_mod.allowed_melee_wpns:
		return false
	elif weapon_stats is ProjWeaponResource and weapon_stats.proj_weapon_type not in weapon_mod.allowed_proj_wpns:
		return false
	return true

func _ready() -> void:
	if not get_parent().is_node_ready():
		await get_parent().ready

	source_entity = get_parent().entity

## Handles an incoming added weapon mod. Removes it first if it already exists and then just re-adds it.
func handle_weapon_mod(weapon_stats: WeaponResource, weapon_mod: WeaponMod, index: int) -> void:
	if not WeaponModManager.check_mod_compatibility(weapon_stats, weapon_mod):
		return

	var i: int = 0
	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		if weapon_mod.id == weapon_mod_entry.keys()[0]:
			if weapon_mod_entry.values()[0] != null:
				remove_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i)
		i += 1

	_add_weapon_mod(weapon_stats, weapon_mod, index)

## Adds a weapon mod to the dictionary and then calls the on_added method inside the mod itself.
func _add_weapon_mod(weapon_stats: WeaponResource, weapon_mod: WeaponMod, index: int) -> void:
	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		print_rich("-------[color=green]Adding[/color][b] " + str(weapon_mod.name) + " (" + str(weapon_mod.rarity) + ")[/b]-------")

	weapon_stats.current_mods[index] = { weapon_mod.id : weapon_mod }

	for mod_resource: StatMod in weapon_mod.wpn_stat_mods:
		weapon_stats.s_mods.add_mods([mod_resource] as Array[StatMod], null)
		_update_effect_source_stats(weapon_stats, mod_resource.stat_id)

	_update_effect_source_status_effects(weapon_stats, false, weapon_mod.status_effects)
	if weapon_stats is MeleeWeaponResource:
		_update_effect_source_status_effects(weapon_stats, true, weapon_mod.charge_status_effects)

	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		_debug_print_status_effect_lists(weapon_stats)

	weapon_mod.on_added(weapon_stats, source_entity)

	if weapon_mod.equipping_audio != "":
		AudioManager.play_sound(weapon_mod.equipping_audio, AudioManager.SoundType.SFX_GLOBAL)

	_update_mod_hud()

## Removes the weapon mod from the dictionary after calling the on_removal method inside the mod itself.
func remove_weapon_mod(weapon_stats: WeaponResource, weapon_mod: WeaponMod, index: int) -> void:
	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates and (weapon_mod.id in weapon_stats.current_mods):
		print_rich("-------[color=red]Removed[/color][b] " + str(weapon_mod.name) + " (" + str(weapon_mod.rarity) + ")[/b]-------")

	for mod_resource: StatMod in weapon_mod.wpn_stat_mods:
		weapon_stats.s_mods.remove_mod(mod_resource.stat_id, mod_resource.mod_id, null)
		_update_effect_source_stats(weapon_stats, mod_resource.stat_id)

	weapon_stats.current_mods[index] = { "EmptySlot" : null }

	_remove_mod_status_effects_from_effect_source(weapon_stats, false)
	if weapon_stats is MeleeWeaponResource:
		_remove_mod_status_effects_from_effect_source(weapon_stats, true)

	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		_debug_print_status_effect_lists(weapon_stats)

	weapon_mod.on_removal(weapon_stats, source_entity)

	if weapon_mod.removal_audio != "":
		AudioManager.play_sound(weapon_mod.removal_audio, AudioManager.SoundType.SFX_GLOBAL)

	_update_mod_hud()

## Adds all mods in the current_mods array to a weapon's stats. Useful for restoring after a save and load.
func add_all_mods_to_weapon(weapon_stats: WeaponResource) -> void:
	var i: int = 0
	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		if weapon_mod_entry.values()[0] != null:
			handle_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i)
		i += 1

## Removes all mods from a passed in weapon_stats resource.
func remove_all_mods_from_weapon(weapon_stats: WeaponResource) -> void:
	var i: int = 0
	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		if weapon_mod_entry.values()[0] != null:
			remove_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i)
		i += 1

## When mods are added or removed that affect the effect source stats, we use this to recalculate them.
func _update_effect_source_stats(weapon_stats: WeaponResource, stat_id: StringName) -> void:
	match stat_id:
		&"base_damage":
			weapon_stats.effect_source.base_damage = weapon_stats.s_mods.get_stat("base_damage")
		&"base_healing":
			weapon_stats.effect_source.base_healing = weapon_stats.s_mods.get_stat("base_healing")
		&"crit_chance":
			weapon_stats.effect_source.crit_chance = weapon_stats.s_mods.get_stat("crit_chance")
		&"armor_penetration":
			weapon_stats.effect_source.armor_penetration = weapon_stats.s_mods.get_stat("armor_penetration")

	if weapon_stats is MeleeWeaponResource: # Projectile weapons don't have separate charge stats since they can only be one firing type
		match(stat_id):
			&"charge_base_damage":
				weapon_stats.charge_effect_source.base_damage = weapon_stats.s_mods.get_stat("charge_base_damage")
			&"charge_base_healing":
				weapon_stats.charge_effect_source.base_healing = weapon_stats.s_mods.get_stat("charge_base_healing")
			&"charge_crit_chance":
				weapon_stats.charge_effect_source.crit_chance = weapon_stats.s_mods.get_stat("charge_crit_chance")
			&"charge_armor_penetration":
				weapon_stats.charge_effect_source.armor_penetration = weapon_stats.s_mods.get_stat("charge_armor_penetration")

## Updates the effect source status effect lists based on an incoming stat mod.
## Handles duplicates by keeping the highest level.
func _update_effect_source_status_effects(weapon_stats: WeaponResource, for_charged: bool,
											new_effects: Array[StatusEffect]) -> void:
	var effect_source: EffectSource = weapon_stats.effect_source if not for_charged else weapon_stats.charge_effect_source

	for new_effect: StatusEffect in new_effects:
		var existing_effect_index: int = effect_source.check_for_effect_and_get_index(new_effect.effect_name)
		if existing_effect_index != -1:
			if new_effect.effect_lvl > effect_source.status_effects[existing_effect_index].effect_lvl:
				effect_source.status_effects[existing_effect_index] = new_effect
		else:
			effect_source.status_effects.append(new_effect)

## Updates the status effect lists after removing a mod (by not using the old mod's status effects anymore).
func _remove_mod_status_effects_from_effect_source(weapon_stats: WeaponResource, for_charged: bool) -> void:
	var effect_source: EffectSource = weapon_stats.effect_source if not for_charged else weapon_stats.charge_effect_source
	var orig_array: Array[StatusEffect] = weapon_stats.original_status_effects if not for_charged else weapon_stats.original_charge_status_effects

	effect_source.status_effects = orig_array.duplicate()

	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		var mod: WeaponMod = weapon_mod_entry.values()[0]
		if mod != null:
			_update_effect_source_status_effects(weapon_stats, for_charged, mod.status_effects if not for_charged else mod.charge_status_effects)

func _update_mod_hud() -> void:
	if not source_entity is Player:
		return

	#var mod_hud: NinePatchRect = weapon.source_entity.get_node("%WeaponModsHUD")
	#for i: int in range(WeaponModManager.MAX_WEAPON_MODS):
		#if weapon.stats.current_mods.size() >= i:
			#mod_hud.update_hud_slot(i, )

## Formats the updated lists of status effects and prints them out.
func _debug_print_status_effect_lists(weapon_stats: WeaponResource) -> void:
	var is_normal_base: bool = true if weapon_stats.effect_source.status_effects == weapon_stats.original_status_effects else false
	print_rich("[color=cyan]Normal Effects[/color]" + ("[color=gray][i](base)[/i][/color]" if is_normal_base else "") + ": [b]"+ str(weapon_stats.effect_source.status_effects) + "[/b]")
	if weapon_stats is MeleeWeaponResource:
		var is_normal_charge: bool = true if weapon_stats.charge_effect_source.status_effects == weapon_stats.original_charge_status_effects else false
		print_rich("[color=cyan]Charge Effects[/color]" + ("[color=gray][i](base)[/i][/color]" if is_normal_charge else "") + ": [b]"+ str(weapon_stats.charge_effect_source.status_effects) + "[/b]")
