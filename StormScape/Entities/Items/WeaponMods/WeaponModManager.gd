class_name WeaponModManager
## A collection of static functions that handle adding, removing, and restoring weapon mods on a weapon.


## Checks if the mod can be attached to the weapon.
static func check_mod_compatibility(weapon_stats: WeaponResource, weapon_mod: WeaponMod) -> bool:
	if weapon_mod.id in weapon_stats.blocked_mods:
		return false
	if weapon_stats is MeleeWeaponResource and weapon_stats.melee_weapon_type not in weapon_mod.allowed_melee_wpns:
		return false
	elif weapon_stats is ProjWeaponResource and weapon_stats.proj_weapon_type not in weapon_mod.allowed_proj_wpns:
		return false
	for blocked_mutual: StringName in weapon_mod.blocked_mutuals:
		if weapon_stats.has_mod(blocked_mutual):
			return false

	var found_blocked_stat: bool = false
	for blocked_stat: StringName in weapon_mod.blocked_wpn_stats:
		if weapon_stats.get_nested_stat(blocked_stat, false) == weapon_mod.blocked_wpn_stats[blocked_stat]:
			found_blocked_stat = true
		else:
			if weapon_mod.req_all_blocked_stats:
				return true
	if found_blocked_stat:
		return false
	return true

## Returns how many mods the weapon can have on it.
static func get_max_mod_slots(weapon_stats: WeaponResource) -> int:
	if weapon_stats.max_mods_override != -1:
		return weapon_stats.max_mods_override
	else:
		return int(weapon_stats.rarity + 1)

## Handles an incoming added weapon mod. Removes it first if it already exists and then just re-adds it.
static func handle_weapon_mod(weapon_stats: WeaponResource, weapon_mod: WeaponMod, index: int,
						source_entity: PhysicsBody2D) -> void:
	if not check_mod_compatibility(weapon_stats, weapon_mod):
		return
	if index > WeaponModManager.get_max_mod_slots(weapon_stats) - 1:
		push_error("\"" + weapon_stats.name + "\" tried to add the mod \"" + weapon_mod.name + "\" to slot " + str(index + 1) + " / 6, but that slot is not unlocked for that weapon.")
		return

	var i: int = 0
	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		if (weapon_mod.id == weapon_mod_entry.keys()[0]) and (weapon_mod_entry.values()[0] != null):
			remove_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i, source_entity)
		elif i == index and weapon_mod_entry.values()[0] != null:
			push_warning("\"" + weapon_mod_entry.keys()[0] + "\" was already in mod slot " + str(i) + " and will now be removed to make room for \"" + weapon_mod.id + "\"")
			remove_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i, source_entity)
		i += 1

	_add_weapon_mod(weapon_stats, weapon_mod, index, source_entity)

## Adds a weapon mod to the dictionary and then calls the on_added method inside the mod itself.
static func _add_weapon_mod(weapon_stats: WeaponResource, weapon_mod: WeaponMod, index: int,
					source_entity: PhysicsBody2D) -> void:
	if DebugFlags.PrintFlags.weapon_mod_changes:
		print_rich("-------[color=green]Adding[/color][b] " + str(weapon_mod.name) + " (" + str(weapon_mod.rarity) + ")[/b]-------")

	weapon_stats.current_mods[index] = { weapon_mod.id : weapon_mod }

	for mod_resource: StatMod in weapon_mod.wpn_stat_mods:
		weapon_stats.s_mods.add_mods([mod_resource] as Array[StatMod], null)
		_update_effect_source_stats(weapon_stats, mod_resource.stat_id)

	_update_effect_source_status_effects(weapon_stats, false, weapon_mod.status_effects)
	if weapon_stats is MeleeWeaponResource:
		_update_effect_source_status_effects(weapon_stats, true, weapon_mod.charge_status_effects)

	if DebugFlags.PrintFlags.weapon_mod_changes:
		_debug_print_status_effect_lists(weapon_stats)

	weapon_mod.on_added(weapon_stats, source_entity.hands.equipped_item if source_entity != null else null)

	if weapon_mod.equipping_audio != "":
		AudioManager.play_sound(weapon_mod.equipping_audio, AudioManager.SoundType.SFX_GLOBAL)

## Removes the weapon mod from the dictionary after calling the on_removal method inside the mod itself.
static func remove_weapon_mod(weapon_stats: WeaponResource, weapon_mod: WeaponMod, index: int,
						source_entity: PhysicsBody2D) -> void:
	if DebugFlags.PrintFlags.weapon_mod_changes and weapon_stats.has_mod(weapon_mod.id):
		print_rich("-------[color=red]Removed[/color][b] " + str(weapon_mod.name) + " (" + str(weapon_mod.rarity) + ")[/b]-------")

	for mod_resource: StatMod in weapon_mod.wpn_stat_mods:
		weapon_stats.s_mods.remove_mod(mod_resource.stat_id, mod_resource.mod_id, null)
		_update_effect_source_stats(weapon_stats, mod_resource.stat_id)

	weapon_stats.current_mods[index] = { "EmptySlot" : null }

	_remove_mod_status_effects_from_effect_source(weapon_stats, false)
	if weapon_stats is MeleeWeaponResource:
		_remove_mod_status_effects_from_effect_source(weapon_stats, true)

	if DebugFlags.PrintFlags.weapon_mod_changes:
		_debug_print_status_effect_lists(weapon_stats)

	weapon_mod.on_removal(weapon_stats, source_entity.hands.equipped_item if source_entity != null else null)

	if weapon_mod.removal_audio != "":
		AudioManager.play_sound(weapon_mod.removal_audio, AudioManager.SoundType.SFX_GLOBAL)

## Adds all mods in the current_mods array to a weapon's stats. Useful for restoring after a save and load.
static func re_add_all_mods_to_weapon(weapon_stats: WeaponResource, source_entity: PhysicsBody2D) -> void:
	var i: int = 0
	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		if weapon_mod_entry.values()[0] != null:
			handle_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i, source_entity)
		i += 1

## Removes all mods from a passed in weapon_stats resource.
static func remove_all_mods_from_weapon(weapon_stats: WeaponResource, source_entity: PhysicsBody2D) -> void:
	var i: int = 0
	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		if weapon_mod_entry.values()[0] != null:
			remove_weapon_mod(weapon_stats, weapon_mod_entry.values()[0], i, source_entity)
		i += 1

## When mods are added or removed that affect the effect source stats, we use this to recalculate them.
static func _update_effect_source_stats(weapon_stats: WeaponResource, stat_id: StringName) -> void:
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
static func _update_effect_source_status_effects(weapon_stats: WeaponResource, for_charged: bool,
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
static func _remove_mod_status_effects_from_effect_source(weapon_stats: WeaponResource, for_charged: bool) -> void:
	var effect_source: EffectSource = weapon_stats.effect_source if not for_charged else weapon_stats.charge_effect_source
	var orig_array: Array[StatusEffect] = weapon_stats.original_status_effects if not for_charged else weapon_stats.original_charge_status_effects

	effect_source.status_effects = orig_array.duplicate()

	for weapon_mod_entry: Dictionary in weapon_stats.current_mods:
		var mod: WeaponMod = weapon_mod_entry.values()[0]
		if mod != null:
			_update_effect_source_status_effects(weapon_stats, for_charged, mod.status_effects if not for_charged else mod.charge_status_effects)

## Resets the original (non-modded) status effects for the weapon after a save so that they correctly reflect
## the effects not provided by mods. This then removes and then readds all the weapon mods from the save.
static func reset_original_arrays_after_save(weapon_stats: WeaponResource, source_entity: PhysicsBody2D) -> void:
	var mods_copy: Array[Dictionary] = weapon_stats.current_mods.duplicate()

	weapon_stats.original_status_effects = []
	if weapon_stats is MeleeWeaponResource:
		weapon_stats.original_charge_status_effects = []
	remove_all_mods_from_weapon(weapon_stats, source_entity)

	weapon_stats.original_status_effects = weapon_stats.effect_source.status_effects
	if weapon_stats is MeleeWeaponResource:
		weapon_stats.original_charge_status_effects = weapon_stats.charge_effect_source.status_effects

	weapon_stats.current_mods = mods_copy
	re_add_all_mods_to_weapon(weapon_stats, source_entity)

## Formats the updated lists of status effects and prints them out.
static func _debug_print_status_effect_lists(weapon_stats: WeaponResource) -> void:
	var is_normal_base: bool = true if weapon_stats.effect_source.status_effects == weapon_stats.original_status_effects else false
	print_rich("[color=cyan]Normal Effects[/color]" + ("[color=gray][i](base)[/i][/color]" if is_normal_base else "") + ": [b]"+ str(weapon_stats.effect_source.status_effects) + "[/b]")
	if weapon_stats is MeleeWeaponResource:
		var is_normal_charge: bool = true if weapon_stats.charge_effect_source.status_effects == weapon_stats.original_charge_status_effects else false
		print_rich("[color=cyan]Charge Effects[/color]" + ("[color=gray][i](base)[/i][/color]" if is_normal_charge else "") + ": [b]"+ str(weapon_stats.charge_effect_source.status_effects) + "[/b]")
