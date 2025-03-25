extends ItemResource
class_name WeaponResource
## The base resource for all weapons. This will be subclasses to define more traits, but everything here applies to all weapons.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var pullout_delay: float = 0.25 ## How long after equipping must we wait before we can use this weapon.
@export_group("Modding Details")
@export_range(0, 6, 1) var max_mods: int = 3 ## The maximum number of mod slots for this weapon.
@export var blocked_mods: Array[StringName] = [] ## The string names of weapon mod titles that are not allowed to be applied to this weapon.


# Unique Properties #
@export_storage var s_mods: StatModsCacheResource = StatModsCacheResource.new() ## The cache of all up to date stats for this weapon with mods factored in.
@export_storage var weapon_mods_need_to_be_readded_after_save: bool = false ## When the weapons are loaded from a save, the weapon mods end up getting added to the old stats reference and not the new duplicated one after load. But since these properties transfer over, we check this each time the weapon is readied to see if we should readd all weapon mods.
@export_storage var current_mods: Array[Dictionary] = [{ &"1" : null }, { &"2" : null }, { &"3" : null }, { &"4" : null }, { &"5" : null }, { &"6" : null }] ## The current mods applied to this weapon. This is an array of dictionaries so that the KV pairs can be ordered. Keys are StringName mod names and values are weapon_mod resources.
@export_storage var original_status_effects: Array[StatusEffect] = [] ## The original status effect list of the effect source before any mods are applied.
@export_storage var original_charge_status_effects: Array[StatusEffect] = [] ## The original status effect list of the charge effect source before any mods are applied.


## Whether the weapon is the same as another weapon when called externally to compare.
## Overrides base method to also compare weapon mods.
func is_same_as(other_item: ItemResource) -> bool:
	return (str(self) == str(other_item)) and (self.current_mods == other_item.current_mods)

## Checks to see if the weapon has the passed in mod already, regardless of level.
func has_mod(mod_id: StringName) -> bool:
	for weapon_mod_entry: Dictionary in current_mods:
		if weapon_mod_entry.values()[0] != null:
			if weapon_mod_entry.keys()[0] == mod_id:
				return true
	return false

## Finds the place a stat is stored at within the resource and returns it. Can optionally get the unmodified stat
## if it exists in the stat mods cache.
func get_nested_stat(stat: StringName, get_original: bool = false) -> float:
	if s_mods.has_stat(stat):
		if not get_original: return s_mods.get_stat(stat)
		else: return s_mods.get_original_stat(stat)
	elif stat in self:
		return get(stat)
	elif stat in get("effect_source"):
		return get("effect_source").get(stat)
	elif "projectile_logic" in self and stat in get("projectile_logic"):
		return get("projectile_logic").get(stat)
	else:
		push_error("Couldn't find the requested stat (" + stat + ") anywhere.")
		return 0
