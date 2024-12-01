extends Node
class_name WeaponModManager
## The manager attached to each weapon that controls all weapon mod logic.

@export_subgroup("Debug")
@export var print_effect_updates: bool = false ## Whether to print when this weapon has mods added and removed. Printing the individual stat changes is decided by the cache resource itself. This only toggles the adding & removing of mod names as well as status effect changes.

@onready var weapon: Weapon = get_parent() ## The weapon that this mod manager works for.


## Handles an incoming added weapon mod. Removes it first if it already exists and then just re-adds it.
func handle_weapon_mod(weapon_mod: WeaponMod) -> void:
	if weapon_mod.mod_name in weapon.stats.blocked_mods:
		return

	if weapon_mod.mod_name in weapon.stats.current_mods:
		_remove_weapon_mod(weapon.stats.current_mods[weapon_mod.mod_name])

	_add_weapon_mod(weapon_mod)

## Adds a weapon mod to the dictionary and then calls the on_added method inside the mod itself.
func _add_weapon_mod(weapon_mod) -> void:
	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		print_rich("-------[color=green]Adding[/color][b] " + str(weapon_mod.mod_name) + str(weapon_mod.mod_lvl) + "[/b]-------")

	weapon.stats.current_mods[weapon_mod.mod_name] = weapon_mod

	for mod_resource in weapon_mod.wpn_stat_mods:
		var mod: StatMod = (mod_resource as StatMod)
		weapon.stats.s_mods.add_mods([mod] as Array[StatMod], null)
		_update_effect_source_stats(mod_resource.stat_id)

	_update_effect_source_status_effects(false, weapon_mod.status_effects)
	_update_effect_source_status_effects(true, weapon_mod.charge_status_effects)

	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		_debug_print_status_effect_lists()

	weapon_mod.on_added(weapon)

	if weapon_mod.equipping_audio != "":
		AudioManager.play_sound(weapon_mod.equipping_audio, AudioManager.SoundType.SFX_GLOBAL)

## Removes the weapon mod from the dictionary after calling the on_removal method inside the mod itself.
func _remove_weapon_mod(weapon_mod: WeaponMod) -> void:
	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		print_rich("-------[color=red]Removed[/color][b] " + str(weapon_mod.mod_name) + str(weapon_mod.mod_lvl) + "[/b]-------")

	for mod_resource in weapon_mod.wpn_stat_mods:
		var mod: StatMod = (mod_resource as StatMod)
		weapon.stats.s_mods.remove_mod(mod.stat_id, mod.mod_id, null)
		_update_effect_source_stats(mod_resource.stat_id)

	if weapon_mod.mod_name in weapon.stats.current_mods:
		weapon.stats.current_mods.erase(weapon_mod.mod_name)

	_remove_mod_status_effects_from_effect_source(false)
	_remove_mod_status_effects_from_effect_source(true)

	if DebugFlags.PrintFlags.weapon_mod_changes and print_effect_updates:
		_debug_print_status_effect_lists()

	weapon_mod.on_removal(weapon)

	if weapon_mod.removal_audio != "":
		AudioManager.play_sound(weapon_mod.removal_audio, AudioManager.SoundType.SFX_GLOBAL)

## Called externally to request that a mod get removed. If the mod was not in dictionary of current mods, nothing happens.
func request_mod_removal(mod_name: String) -> void:
	var existing_mod: WeaponMod = weapon.stats.current_mods.get(mod_name, null)
	if existing_mod: _remove_weapon_mod(existing_mod)

## When mods are added or removed that affect the effect source stats, we use this to recalculate them.
func _update_effect_source_stats(stat_id: String) -> void:
	match stat_id:
		"base_damage":
			weapon.stats.effect_source.base_damage = weapon.stats.s_mods.get_stat("base_damage")
		"base_healing":
			weapon.stats.effect_source.base_healing = weapon.stats.s_mods.get_stat("base_healing")
		"crit_chance":
			weapon.stats.effect_source.crit_chance = weapon.stats.s_mods.get_stat("crit_chance")
		"armor_penetration":
			weapon.stats.effect_source.armor_penetration = weapon.stats.s_mods.get_stat("armor_penetration")
		"charge_base_damage":
			weapon.stats.charge_effect_source.base_damage = weapon.stats.s_mods.get_stat("base_damage")
		"charge_base_healing":
			weapon.stats.charge_effect_source.base_healing = weapon.stats.s_mods.get_stat("base_healing")
		"charge_crit_chance":
			weapon.stats.charge_effect_source.crit_chance = weapon.stats.s_mods.get_stat("crit_chance")
		"charge_armor_penetration":
			weapon.stats.charge_effect_source.armor_penetration = weapon.stats.s_mods.get_stat("armor_penetration")

## Updates the effect source status effect lists based on an incoming stat mod. Handles duplicates by keeping the highest level.
func _update_effect_source_status_effects(for_charged: bool, new_effects: Array[StatusEffect]) -> void:
	var effect_source: EffectSource = weapon.stats.effect_source if not for_charged else weapon.stats.charge_effect_source

	for new_effect in new_effects:
		var existing_effect_index: int = effect_source.check_for_effect_and_get_index(new_effect.effect_name)
		if existing_effect_index != -1:
			if new_effect.effect_lvl > effect_source.status_effects[existing_effect_index].effect_lvl:
				effect_source.status_effects[existing_effect_index] = new_effect
		else:
			effect_source.status_effects.append(new_effect)

## Updates the status effect lists after removing a mod (by not using the old mod's status effects anymore).
func _remove_mod_status_effects_from_effect_source(for_charged: bool) -> void:
	var effect_source: EffectSource = weapon.stats.effect_source if not for_charged else weapon.stats.charge_effect_source
	var orig_array: Array[StatusEffect] = weapon.stats.original_status_effects if not for_charged else weapon.stats.original_charge_status_effects

	effect_source.status_effects = orig_array.duplicate()

	for mod in weapon.stats.current_mods.values():
		_update_effect_source_status_effects(for_charged, mod.status_effects if not for_charged else mod.charge_status_effects)

## Formats the updated lists of status effects and prints them out.
func _debug_print_status_effect_lists() -> void:
	var is_normal_base: bool = true if weapon.stats.effect_source.status_effects == weapon.stats.original_status_effects else false
	var is_normal_charge: bool = true if weapon.stats.charge_effect_source.status_effects == weapon.stats.original_charge_status_effects else false
	print_rich("[color=cyan]Normal Effects[/color]" + ("[color=gray][i](base)[/i][/color]" if is_normal_base else "") + ": [b]"+ str(weapon.stats.effect_source.status_effects) + "[/b]")
	print_rich("[color=cyan]Charge Effects[/color]" + ("[color=gray][i](base)[/i][/color]" if is_normal_charge else "") + ": [b]"+ str(weapon.stats.charge_effect_source.status_effects) + "[/b]")
