@icon("res://Utilities/Debug/EditorIcons/weapon_mod.svg")
extends WeaponMod
class_name ExtendedMagMod
## Implements logic specific to the extended mag mod, mainly to update the UI and reset ammo count on mod removal.


func on_added(weapon_stats: WeaponResource, source_entity: PhysicsBody2D) -> void:
	if weapon_stats is ProjWeaponResource:
		# When removed and readded on load, the on_removal will set it to the original size if it was above it, so this just undoes that
		if weapon_stats.ammo_in_mag >= weapon_stats.s_mods.get_original_stat("mag_size"):
			weapon_stats.ammo_in_mag = weapon_stats.s_mods.get_stat("mag_size")
			var equipped_item: EquippableItem = source_entity.hands.equipped_item
			if equipped_item != null and weapon_stats == equipped_item.stats:
				equipped_item._update_ammo_ui()

func on_removal(weapon_stats: WeaponResource, source_entity: PhysicsBody2D) -> void:
	if weapon_stats is ProjWeaponResource:
		weapon_stats.ammo_in_mag = min(weapon_stats.ammo_in_mag, weapon_stats.s_mods.get_stat("mag_size"))
		var equipped_item: EquippableItem = source_entity.hands.equipped_item
		if equipped_item != null and weapon_stats == equipped_item.stats:
			equipped_item._update_ammo_ui()
