extends ItemResource
class_name WeaponResource
## The base resource for all weapons.

const BASE_XP_FOR_LVL: int = 100
const LVL_SCALING_EXPONENT: float = 1.025
const RARITY_LEVELING_FACTOR: float = 0.2
const MAX_LEVEL: int = 40
const TINY_XP: int = 2
const SMALL_XP: int = 5
const MEDIUM_XP: int = 25
const MEDIUM_LARGE_XP: int = 50
const LARGE_XP: int = 100
const HUGE_XP: int = 250
const ENORMOUS_XP: int = 500
const EFFECT_AMOUNT_XP_MULT: float = 0.35 ## Multiplies effect src amounts (dmg, heal) before adding that amount as xp.

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var pullout_delay: float = 0.25 ## How long after equipping must we wait before we can use this weapon.
@export var snap_to_six_dirs: bool = false ## When true, free rotation of the sprite is disabled and will snap to six predefined directions.
@export var no_levels: bool = false ## When true, this weapon does not engage with the weapon leveling system.
@export var hide_ammo_ui: bool = false ## Whether to hide the ammo UI when the player uses this weapon.
@export_group("Modding Details")
@export_range(-1, 6, 1) var max_mods_override: int = -1 ## The override for the maximum number of mod slots for this weapon. By default it is based on rarity. Anything other than -1 will activate the override.
@export var blocked_mods: Array[StringName] = [] ## The string names of weapon mod titles that are not allowed to be applied to this weapon.


# Unique Properties #
@export_custom(PROPERTY_HINT_RANGE, "1,40,1", PROPERTY_USAGE_STORAGE) var level: int = 1 ## The level for this weapon.
@export_storage var lvl_progress: int ## Any xp gained towards the progress of the next level is stored here.
@export_storage var s_mods: StatModsCacheResource = StatModsCacheResource.new() ## The cache of all up to date stats for this weapon with mods factored in.
@export_storage var weapon_mods_need_to_be_readded_after_save: bool = false ## When the weapons are loaded from a save, the weapon mods end up getting added to the old stats reference and not the new duplicated one after load. But since these properties transfer over, we check this each time the weapon is readied to see if we should readd all weapon mods.
@export_storage var current_mods: Array[Dictionary] = [{ &"1" : null }, { &"2" : null }, { &"3" : null }, { &"4" : null }, { &"5" : null }, { &"6" : null }] ## The current mods applied to this weapon. This is an array of dictionaries so that the KV pairs can be ordered. Keys are StringName mod names and values are weapon_mod resources.
@export_storage var original_status_effects: Array[StatusEffect] = [] ## The original status effect list of the effect source before any mods are applied.
@export_storage var original_charge_status_effects: Array[StatusEffect] = [] ## The original status effect list of the charge effect source before any mods are applied.
@export_storage var original_aoe_status_effects: Array[StatusEffect] = [] ## The original status effect list of the aoe effect source before any mods are applied.

## Returns the amount of xp we need to attain the next level that we aren't at yet.
static func xp_needed_for_lvl(weapon_stats: WeaponResource, lvl: int) -> int:
	var rarity_mult: float = 1 + (weapon_stats.rarity * RARITY_LEVELING_FACTOR)

	# Subtract one iteration at the end since we start at level 1
	return int(BASE_XP_FOR_LVL * pow(lvl, LVL_SCALING_EXPONENT) * rarity_mult) - int(BASE_XP_FOR_LVL * rarity_mult)

## Whether the weapon is the same as another weapon when called externally to compare.
## Overrides base method to also compare weapon mods.
func is_same_as(other_item: ItemResource) -> bool:
	return (str(self) == str(other_item)) and (self.current_mods == other_item.current_mods)

## Checks to see if the weapon has the passed in mod already, regardless of level.
func has_mod(mod_id: StringName, index: int = -1) -> bool:
	var i: int = 0
	for weapon_mod_entry: Dictionary in current_mods:
		if weapon_mod_entry.values()[0] != null:
			if weapon_mod_entry.keys()[0] == mod_id:
				if index != -1:
					if i == index:
						return true
					else:
						i += 1
						continue
				return true
		i += 1
	return false

## Returns true if this weapon resource has any mods at all.
func has_any_mods() -> bool:
	for weapon_mod_entry: Dictionary in current_mods:
		if weapon_mod_entry.values()[0] != null:
			return true
	return false

## Adds xp to the weapon, potentially leveling it up if it has reached enough accumulation of xp. Returns true
## if a level up occurred as a result of the added xp.
func add_xp(amount: int) -> bool:
	if no_levels:
		return false

	var leveled_up: bool = false

	lvl_progress += amount
	while level < MAX_LEVEL:
		var xp_needed: int = xp_needed_for_lvl(self, level + 1)
		if lvl_progress >= xp_needed and xp_needed > 0:
			lvl_progress -= xp_needed
			level += 1
			leveled_up = true
		else:
			break

	if level == MAX_LEVEL:
		lvl_progress = 0

	if Globals.player_node.hands.do_these_stats_match_equipped_item(self):
		var idx: int = Globals.player_node.hands.equipped_item.inv_index
		Globals.player_node.inv.inv_data_updated.emit(idx, Globals.player_node.inv.inv[idx])

	if DebugFlags.weapon_xp_updates:
		var xp_needed_now: int = xp_needed_for_lvl(self, level + 1)
		print("AMOUNT: ", amount, " | PROGRESS: ", lvl_progress, " | LEVEL: ", level, " | REMAINING_NEEDED: ", xp_needed_now - lvl_progress)

	return leveled_up

## prints the total needed xp for each level up to the requested level.
func print_total_needed(for_level: int) -> void:
	print("-------------------------------------------------------------------------")
	var total: int = 0
	for lvl: int in range(1, for_level + 1):
		var xp: int = xp_needed_for_lvl(self, lvl)
		total += xp
		print("LVL: ", lvl, " | LVL_XP: ", xp, " | TOTAL: ", total)
