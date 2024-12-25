extends WeaponMod
class_name ExtendedMagMod
## Implements logic specific to the extended mag mod, mainly to update the UI and reset ammo count on mod removal.


func on_added(_weapon: Weapon) -> void:
	pass

func on_removal(weapon: Weapon) -> void:
	if weapon is ProjectileWeapon:
		weapon.stats.ammo_in_mag = min(weapon.stats.ammo_in_mag, weapon.stats.s_mods.get_stat("mag_size"))
		weapon._update_ammo_ui()
