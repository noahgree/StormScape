@icon("res://Utilities/Debug/EditorIcons/weapon_mod.svg")
extends WeaponMod
class_name ExtendedMagMod
## Implements logic specific to the extended mag mod, mainly to update the UI and reset ammo count on mod removal.


func on_added(weapon_stats: WeaponResource, weapon: Weapon) -> void:
	if weapon_stats is ProjWeaponResource:
		# When removed and readded on load, the on_removal will set it to the original size if it was above it, so this just undoes that
		if weapon_stats.ammo_in_mag >= weapon_stats.s_mods.get_original_stat("mag_size"):
			weapon_stats.ammo_in_mag = weapon_stats.s_mods.get_stat("mag_size")
			# Must check if it is null since the mod manager may call this for inventory items and not only equipped items
			if weapon != null and weapon_stats == weapon.stats:
				weapon._update_ammo_ui()

func on_removal(weapon_stats: WeaponResource, weapon: Weapon) -> void:
	if weapon_stats is ProjWeaponResource:
		weapon_stats.ammo_in_mag = min(weapon_stats.ammo_in_mag, weapon_stats.s_mods.get_stat("mag_size"))
		if weapon != null and weapon_stats == weapon.stats:
			weapon._update_ammo_ui()
