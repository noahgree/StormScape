class_name ItemDetailsCreator
## Creates details for a passed in item, conditional on what the item type and potential mods are.

var up_green: String = "[color=Lawngreen][char=21A5][/color]" ## An upwards, green arrow.
var up_red: String = "[color=Red][char=21A5][/color]" ## An upwards, red arrow.
var down_green: String = "[color=Lawngreen][char=21A7][/color]" ## A downwards, green arrow.
var down_red: String = "[color=Red][char=21A7][/color]" ## A downwards, red arrow.


## Parses the item passed in based on its type and returns an array of strings as the resulting details.
func parse_item(stats: ItemResource) -> Array[String]:
	var strings: Array[String] = []

	match stats.item_type:
		Globals.ItemType.CONSUMABLE:
			strings.append(_get_health_bars_change(stats))
			strings.append(_get_damage(stats))
			strings.append(_get_healing(stats))
			strings.append(_get_use_speed(stats))
		Globals.ItemType.WEAPON:
			strings.append(_get_ammo_type(stats))
			strings.append(_get_damage(stats))
			strings.append(_get_charge_damage(stats))
			strings.append(_get_healing(stats))
			strings.append(_get_charge_healing(stats))
			strings.append(_get_use_speed(stats))
			strings.append(_get_mag_and_reload(stats))
			strings.append(_get_bloom(stats))
			strings.append(_get_status_effects(stats))
			strings.append(_get_charge_status_effects(stats))
			strings.append_array(_get_aoe_stats(stats))
		Globals.ItemType.AMMO:
			pass
		Globals.ItemType.WEARABLE:
			pass
		Globals.ItemType.WORLD_RESOURCE:
			pass
		Globals.ItemType.SPECIAL:
			pass
		Globals.ItemType.WEAPON_MOD:
			strings.append_array(_get_allowed_weapons_for_mod(stats))

	strings.append_array(_get_extra_details(stats, stats.extra_details, false, false))
	if stats is WeaponResource:
		strings.append_array(_get_weapon_mod_extra_details(stats))

	strings = strings.filter(func(string: String) -> bool: return string != "")
	return strings

## Parses the information to populate in the player stats viewer.
func parse_player() -> Array[String]:
	var strings: Array[String] = []
	strings.append(_get_title("MAX HEALTH") + _get_player_sum(["max_health"], true))
	strings.append(_get_title("MAX SHIELD") + _get_player_sum(["max_shield"], true))
	strings.append(_get_title("MAX STAMINA") + _get_player_sum(["max_stamina"], true))
	strings.append(_get_title("MAX HUNGER BARS") + _get_player_sum(["max_hunger_bars"], true))

	for wearable_dict: Dictionary in Globals.player_node.wearables:
		var wearable: Wearable = wearable_dict.values()[0]
		if wearable != null:
			strings.append_array(_get_extra_details(wearable, wearable.applied_details, true, true))

	strings = strings.filter(func(string: String) -> bool: return string != "")
	return strings

## Gets an array of additional detail strings created by the mods attached to the weapon.
func _get_weapon_mod_extra_details(stats: WeaponResource) -> Array[String]:
	var strings: Array[String] = []
	for weapon_mod_entry: Dictionary in stats.current_mods:
		if weapon_mod_entry.values()[0] != null:
			strings.append_array(_get_extra_details(stats, weapon_mod_entry.values()[0].applied_details, true, false))

	return strings

## Returns an array of additional detail strings from given StatDetail resources.
func _get_extra_details(stats: ItemResource, extra_details_array: Array[StatDetail],
							highlight_when_title_only: bool, for_entity_stats: bool = false) -> Array[String]:
	var strings: Array[String] = []
	for detail: StatDetail in extra_details_array:
		if not detail.stat_array.is_empty():
			var detail_sum: String
			if not for_entity_stats:
				detail_sum = _get_item_sums(stats, detail.stat_array, detail.up_is_good, detail.suffix, detail.multiplier, detail.addition, detail.fraction_of_orig)
			else:
				detail_sum = _get_player_sum(detail.stat_array, detail.up_is_good, detail.suffix, detail.multiplier, detail.addition, detail.fraction_of_orig)
			strings.append(_get_title(detail.title) + detail_sum)
		else:
			if highlight_when_title_only:
				strings.append("[color=Lawngreen]" + detail.title + "[/color]" + Globals.invis_char)
			else:
				strings.append(_get_title(detail.title))

	return strings

## Gets the damage details.
func _get_damage(stats: ItemResource) -> String:
	var string: String = _get_title("DMG")
	var proj_count: int = stats.barrage_count * stats.projectiles_per_fire if stats is ProjWeaponResource else 1.0
	var dmg: String = _get_item_sums(stats, ["base_damage"], true, "", proj_count)
	var crit_mult: String = str(stats.effect_source.crit_multiplier) + "x"

	string += dmg
	if stats.effect_source.crit_chance > 0:
		string += " (" + crit_mult + " crit)"

	if not stats is WeaponResource:
		if float(dmg) == 0:
			string = ""

	return string

## Gets the charge damage details for melee weapons.
func _get_charge_damage(stats: ItemResource) -> String:
	if not stats is MeleeWeaponResource:
		return ""
	elif not stats.can_do_charge_use:
		return ""

	var string: String = _get_title("CHRG DMG")
	var dmg: String = _get_item_sums(stats, ["charge_base_damage"], true)
	var crit_mult: String = str(stats.charge_effect_source.crit_multiplier) + "x"

	string += dmg
	if stats.charge_effect_source.crit_chance > 0:
		string += " (" + crit_mult + " crit)"

	return string

## Gets the healing details.
func _get_healing(stats: ItemResource) -> String:
	if stats.effect_source.base_healing == 0:
		return ""

	return _get_title("HEAL") + _get_item_sums(stats, ["base_healing"], true)

## Gets the charge healing details for melee weapons.
func _get_charge_healing(stats: ItemResource) -> String:
	if not stats is MeleeWeaponResource:
		return ""
	elif not stats.can_do_charge_use:
		return ""
	elif stats.charge_effect_source.base_healing == 0:
		return ""

	return _get_title("CHRG HEAL") + _get_item_sums(stats, ["charge_base_healing"], true)

func _get_health_bars_change(stats: ItemResource) -> String:
	var string: String = _get_title("FOOD VALUE")
	string += _get_item_sums(stats, ["hunger_bar_gain"], true)
	return string

## Gets the attack speed details.
func _get_use_speed(stats: ItemResource) -> String:
	var string: String

	if stats is ProjWeaponResource:
		string = _get_title("FIRE RATE")
		var sum: String
		if stats.firing_mode != ProjWeaponResource.FiringType.CHARGE:
			sum = _get_item_sums(stats, ["firing_duration", "fire_cooldown"], false, "s")
		else:
			sum = _get_item_sums(stats, ["firing_duration", "fire_cooldown", "min_charge_time"], false, "s")

		string += StringHelpers.remove_trailing_zero(sum)
	elif stats is MeleeWeaponResource:
		string = _get_title("USE SPEED")
		string += _get_item_sums(stats, ["use_speed", "use_cooldown"], false, "s")

		if stats.can_do_charge_use:
			var chg_sum: String = _get_item_sums(stats, ["min_charge_time", "charge_use_speed", "charge_use_cooldown"], false, "s")
			string += " (" + chg_sum + " chrg)"
	elif stats is ConsumableResource:
		string = _get_title("CONSUMPTION SPEED")
		string += _get_item_sums(stats, ["consumption_time", "consumption_cooldown"], false, "s")

	return string

## Gets the ammo type string used by the weapon.
func _get_ammo_type(stats: WeaponResource) -> String:
	var string: String = _get_title("AMMO TYPE")
	if stats is ProjWeaponResource:
		if stats.ammo_type in [ProjWeaponResource.ProjAmmoType.NONE, ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.CHARGES]:
			return ""
		string += stats.get_ammo_string()
	else:
		return ""
	return string

## Gets the magazine ammo and reload time details. Gets stamina use for melee weapons.
func _get_mag_and_reload(stats: ItemResource) -> String:
	var string: String = _get_title("MAG")

	if stats is MeleeWeaponResource:
		string = _get_title("STAMINA USE")
		string += _get_item_sums(stats, ["stamina_cost"], false)

		if stats.can_do_charge_use:
			var chg_stamina: String = _get_item_sums(stats, ["charge_stamina_cost"], false)
			string += " (" + chg_stamina + " chrg)"

		return string

	if stats.dont_consume_ammo:
		return ""

	var ammo: String = _get_item_sums(stats, ["mag_size"], true)
	var reload: String

	if stats.reload_type == ProjWeaponResource.ReloadType.SINGLE:
		var mult: float = ceilf(stats.s_mods.get_stat("mag_size") / stats.s_mods.get_stat("single_reload_quantity"))
		reload = _get_item_sums(stats, ["single_proj_reload_time", "reload_delay"], false, "s", mult)
	else:
		reload = _get_item_sums(stats, ["mag_reload_time", "reload_delay"], false, "s")

	if stats.mag_size == -1 and stats.ammo_type != ProjWeaponResource.ProjAmmoType.STAMINA:
		return _get_title("RELOAD") + reload
	elif stats.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
		return _get_title("STAMINA USE") + _get_item_sums(stats, ["stamina_use_per_proj"], false)

	return string + ammo + " (" + reload + " [char=21BA])"

## Gets the bloom details.
func _get_bloom(stats: ItemResource) -> String:
	if stats is MeleeWeaponResource or stats.max_bloom == 0:
		return ""

	return _get_title("MAX BLOOM") + _get_item_sums(stats, ["max_bloom"], false, "[char=00B0]")

## Gets the status effects from the normal effect source.
func _get_status_effects(stats: ItemResource) -> String:
	var string: String = _get_title("EFFECTS")

	for effect: StatusEffect in stats.effect_source.status_effects:
		if effect not in stats.original_status_effects:
			string += "[color=Lawngreen]" + effect.get_pretty_string() + "[/color], "
		else:
			string += effect.get_pretty_string() + ", "

	string = string.trim_suffix(", ")
	if stats.effect_source.status_effects.is_empty():
		string = ""

	return string

## Gets the status effects from the charged effect source.
func _get_charge_status_effects(stats: ItemResource) -> String:
	if stats is not MeleeWeaponResource:
		return ""
	elif not stats.can_do_charge_use:
		return ""

	var string: String = _get_title("CHRG EFFECTS")

	for effect: StatusEffect in stats.charge_effect_source.status_effects:
		if effect not in stats.original_charge_status_effects:
			string += "[color=Lawngreen]" + effect.get_pretty_string() + "[/color], "
		else:
			string += effect.get_pretty_string() + ", "

	string = string.trim_suffix(", ")
	if stats.charge_effect_source.status_effects.is_empty():
		string = ""

	return string

## Gets the aoe radius for the weapon if it can do aoe.
func _get_aoe_stats(stats: WeaponResource) -> Array[String]:
	if stats is not ProjWeaponResource:
		return [""]
	elif stats.s_mods.get_stat("proj_aoe_radius") == 0:
		return [""]
	elif stats.projectile_logic.aoe_effect_source.status_effects.size() == 0:
		return[""]

	var strings: Array[String] = [_get_title("AOE RADIUS") + _get_item_sums(stats, ["proj_aoe_radius"], true, " px")]

	var damage: String = _get_title("AOE DMG")
	if stats.s_mods.get_stat("proj_aoe_base_damage") > 0:
		damage += _get_item_sums(stats, ["proj_aoe_base_damage"], true)
		strings.append(damage)

	var healing: String = _get_title("AOE HEAL")
	if stats.s_mods.get_stat("proj_aoe_base_healing") > 0:
		healing += _get_item_sums(stats, ["proj_aoe_base_healing"], true)
		strings.append(healing)

	var effects: String = _get_title("AOE EFFECTS")
	for effect: StatusEffect in stats.projectile_logic.aoe_effect_source.status_effects:
		if effect not in stats.original_aoe_status_effects:
			effects += "[color=Lawngreen]" + effect.get_pretty_string() + "[/color], "
		else:
			effects += effect.get_pretty_string() + ", "
	effects = effects.trim_suffix(", ")
	strings.append(effects)

	return strings

## Gets the list of allowed proj and melee weapon types for a mod.
func _get_allowed_weapons_for_mod(stats: WeaponMod) -> Array[String]:
	var ranged_string: String = _get_title("RANGED COMPATIBILES") + "\n"
	var melee_string: String = _get_title("MELEE COMPATIBILES") + "\n"

	for compat_proj: ProjWeaponResource.ProjWeaponType in stats.allowed_proj_wpns:
		ranged_string += ProjWeaponResource.ProjWeaponType.keys()[compat_proj].capitalize() + ", "
	ranged_string = ranged_string.trim_suffix(", ")
	if stats.allowed_proj_wpns.is_empty():
		ranged_string = ""

	for compat_melee: MeleeWeaponResource.MeleeWeaponType in stats.allowed_melee_wpns:
		melee_string += MeleeWeaponResource.MeleeWeaponType.keys()[compat_melee].capitalize() + ", "
	melee_string = melee_string.trim_suffix(", ")
	if stats.allowed_melee_wpns.is_empty():
		melee_string = ""

	return [ranged_string, melee_string]

## Formats the line title with the needed color and invisible char.
func _get_title(title: String) -> String:
	return "[outline_color=1f0900ab][color=f5e4e1]" + title + ":[/color]" + Globals.invis_char + "[/outline_color][outline_color=1f090066]"

## Gets the sum (index 0) and original sum (index 1) for a list of stats inside an item.
func _get_item_stat_sums(stats: ItemResource, list: Array[String]) -> Array[float]:
	var sum: float = 0
	var original_sum: float = 0

	for stat: String in list:
		sum += stats.get_nested_stat(stat, false)
		original_sum += stats.get_nested_stat(stat, true)

	return [sum, original_sum]

## Gets the sum (index 0) and original sum (index 1) for a list of stats on the player.
func _get_players_stat_sums(list: Array[String]) -> Array[float]:
	var sum: float = 0
	var original_sum: float = 0

	for stat: String in list:
		sum += Globals.player_node.stats.get_stat(stat)
		original_sum += Globals.player_node.stats.get_original_stat(stat)

	return [sum, original_sum]

## Gets a sum of an array of stat ids and compares it to the original sum. Mods that lower or raise sums will
## result in an arrow at the end in the direction of change, colored based on whether higher is better or not.
func _get_item_sums(stats: ItemResource, list: Array[String], up_is_good: bool, suffix: String = "",
				mult: float = 1.0, addition: float = 0.0, fraction_of_original: bool = false) -> String:
	var sums: Array[float] = _get_item_stat_sums(stats, list)
	var sum: float = sums[0]
	var original_sum: float = sums[1]

	return _get_formatted_sum_result(sum, original_sum, up_is_good, suffix, mult, addition, fraction_of_original)

## Gets a sum of an array of stat ids and compares it to the original sum. Stat changers (like wearables
## and status effects) that lower or raise sums will result in an arrow at the end in the direction
## of change, colored based on whether higher is better or not.
func _get_player_sum(list: Array[String], up_is_good: bool, suffix: String = "",
				mult: float = 1.0, addition: float = 0.0, fraction_of_original: bool = false) -> String:
	var sums: Array[float] = _get_players_stat_sums(list)
	var sum: float = sums[0]
	var original_sum: float = sums[1]

	return _get_formatted_sum_result(sum, original_sum, up_is_good, suffix, mult, addition, fraction_of_original)

## Formats the sum result string based on several parameters.
func _get_formatted_sum_result(sum: float, original_sum: float, up_is_good: bool, suffix: String = "",
								mult: float = 1.0, addition: float = 0.0,
								fraction_of_original: bool = false) -> String:
	var arrow: String = ""
	if (sum > original_sum) and up_is_good:
		arrow = up_green
	elif (sum > original_sum) and not up_is_good:
		arrow = up_red
	elif (sum < original_sum) and up_is_good:
		arrow = down_red
	elif (sum < original_sum) and not up_is_good:
		arrow = down_green

	var str_sum: String
	if not fraction_of_original:
		sum *= mult
		sum += addition
		str_sum = StringHelpers.remove_trailing_zero(str(snapped(sum, 0.001)))
	else:
		var division_result: float = sum / original_sum
		division_result *= mult
		division_result += addition
		str_sum = StringHelpers.remove_trailing_zero(str(snapped(division_result, 0.001)))

	return str_sum + suffix + arrow
