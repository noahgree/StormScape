extends WeaponMod
class_name ExtendedMagMod
## Implements logic specific to the extended mag mod, mainly to update the UI and reset ammo count on mod removal.


func on_added(weapon: Weapon) -> void:
	if weapon is ProjectileWeapon:
		# When removed and readded on load, the on_removal will set it to the original size if it was above it, so this just undoes that
		if weapon.stats.ammo_in_mag >= weapon.stats.s_mods.get_original_stat("mag_size"):
			weapon.stats.ammo_in_mag = weapon.stats.s_mods.get_stat("mag_size")
			weapon._update_ammo_ui()

func on_removal(weapon: Weapon) -> void:
	if weapon is ProjectileWeapon:
		weapon.stats.ammo_in_mag = min(weapon.stats.ammo_in_mag, weapon.stats.s_mods.get_stat("mag_size"))
		weapon._update_ammo_ui()
