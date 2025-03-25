extends Node
class_name ItemDetailsCreator
## Creates details for a passed in item, conditional on what the item type and potential mods are.

var up_green: String = "[color=Lawngreen][char=21A5][/color]"
var up_red: String = "[color=Red][char=21A5][/color]"
var down_green: String = "[color=Lawngreen][char=21A7][/color]"
var down_red: String = "[color=Red][char=21A7][/color]"

func parse_item(stats: ItemResource) -> Array[String]:
	var strings: Array[String] = []

	match stats.item_type:
		GlobalData.ItemType.CONSUMABLE:
			pass
		GlobalData.ItemType.WEAPON:
			strings.append(_get_damage(stats))
			strings.append(_get_charge_damage(stats))
			strings.append(_get_healing(stats))
			strings.append(_get_charge_healing(stats))
			strings.append(_get_attack_speed(stats))
			strings.append(_get_ammo_and_reload(stats))
			strings.append(_get_bloom(stats))
			strings.append(_get_status_effects(stats))
			strings.append(_get_charge_status_effects(stats))
		GlobalData.ItemType.AMMO:
			pass
		GlobalData.ItemType.CLOTHING:
			pass
		GlobalData.ItemType.WORLD_RESOURCE:
			pass
		GlobalData.ItemType.SPECIAL:
			pass
		GlobalData.ItemType.WEAPON_MOD:
			pass

	strings.append_array(_get_extra_details(stats, stats.extra_details, false))
	if stats is WeaponResource:
		strings.append_array(_get_weapon_mod_extra_details(stats))

	strings = strings.filter(func(string: String) -> bool: return string != "")
	return strings

func _get_weapon_mod_extra_details(stats: WeaponResource) -> Array[String]:
	var strings: Array[String] = []
	for weapon_mod_entry: Dictionary in stats.current_mods:
		if weapon_mod_entry.values()[0] != null:
			strings.append_array(_get_extra_details(stats, weapon_mod_entry.values()[0].applied_details, true))

	return strings

func _get_extra_details(stats: ItemResource, extra_details_array: Array[ItemDetail],
							highlight_when_title_only: bool) -> Array[String]:
	var strings: Array[String] = []
	for detail: ItemDetail in extra_details_array:
		if not detail.stat_array.is_empty():
			var detail_sum: String = _get_sum(stats, detail.stat_array, detail.up_is_good, detail.suffix)
			strings.append(detail.title + ":" + GlobalData.invis_char + detail_sum)
		else:
			if highlight_when_title_only:
				strings.append("[color=Lawngreen]" + detail.title + "[/color]" + GlobalData.invis_char)
			else:
				strings.append(detail.title + GlobalData.invis_char)

	return strings

func _get_damage(stats: ItemResource) -> String:
	var string: String = "DMG:" + GlobalData.invis_char
	var dmg: String = _get_sum(stats, ["base_damage"], true)
	var crit_mult: String = str(stats.effect_source.crit_multiplier) + "x"

	string += dmg
	if stats.effect_source.crit_chance > 0:
		string += " (" + crit_mult + " crit)"

	return string

func _get_charge_damage(stats: ItemResource) -> String:
	if not stats is MeleeWeaponResource:
		return ""
	elif not stats.can_do_charge_use:
		return ""

	var string: String = "CHRG DMG:" + GlobalData.invis_char
	var dmg: String = _get_sum(stats, ["charge_base_damage"], true)
	var crit_mult: String = str(stats.charge_effect_source.crit_multiplier) + "x"

	string += dmg
	if stats.charge_effect_source.crit_chance > 0:
		string += " (" + crit_mult + " crit)"

	return string

func _get_healing(stats: ItemResource) -> String:
	if stats.effect_source.base_healing == 0:
		return ""

	return "HEAL:" + GlobalData.invis_char + _get_sum(stats, ["base_healing"], true)

func _get_charge_healing(stats: ItemResource) -> String:
	if not stats is MeleeWeaponResource:
		return ""
	elif not stats.can_do_charge_use:
		return ""
	elif stats.charge_effect_source.base_healing == 0:
		return ""

	return "CHRG HEAL:" + GlobalData.invis_char + _get_sum(stats, ["charge_base_healing"], true)

func _get_attack_speed(stats: ItemResource) -> String:
	var string: String = "RATE:" + GlobalData.invis_char

	if stats is ProjWeaponResource:
		var sum: String
		if stats.firing_mode != "Charge":
			sum = _get_sum(stats, ["firing_duration", "fire_cooldown"], false, "s")
		else:
			sum = _get_sum(stats, ["firing_duration", "fire_cooldown", "min_charge_time"], false, "s")

		string += sum.replace(".0", "")
	else:
		string += _get_sum(stats, ["use_speed", "cooldown"], false, "s").replace(".0", "")

		if stats.can_do_charge_use:
			var chg_sum: String = _get_sum(stats, ["min_charge_time", "charge_use_speed", "charge_use_cooldown"], false, "s")
			string += " (" + chg_sum + " chrg)"
	return string

func _get_ammo_and_reload(stats: ItemResource) -> String:
	var string: String = "MAG:" + GlobalData.invis_char

	if stats is MeleeWeaponResource:
		string = "STAMINA USE:" + GlobalData.invis_char
		string += _get_sum(stats, ["stamina_cost"], false)

		if stats.can_do_charge_use:
			var chg_stamina: String = _get_sum(stats, ["charge_stamina_cost"], false)
			string += " (" + chg_stamina + " chrg)"

		return string

	var ammo: String = _get_sum(stats, ["mag_size"], true).replace(".0", "")
	var reload: String

	if stats.reload_type == "Single":
		var mult: float = ceilf(stats.s_mods.get_stat("mag_size") / stats.s_mods.get_stat("single_reload_quantity"))
		reload = _get_sum(stats, ["single_proj_reload_time", "single_proj_reload_delay"], false, "s", mult)
	else:
		reload = _get_sum(stats, ["mag_reload_time"], false, "s")

	if stats.mag_size == -1:
		return "RELOAD:" + GlobalData.invis_char + reload

	return string + ammo + " (" + reload + " [char=21BA])"

func _get_bloom(stats: ItemResource) -> String:
	if stats is MeleeWeaponResource or stats.max_bloom == 0:
		return ""

	return "MAX BLOOM:" + GlobalData.invis_char + _get_sum(stats, ["max_bloom"], false, "[char=00B0]")

func _get_status_effects(stats: ItemResource) -> String:
	var string: String = "EFFECTS:" + GlobalData.invis_char

	for effect: StatusEffect in stats.effect_source.status_effects:
		if effect not in stats.original_status_effects:
			string += "[color=Lawngreen]" + effect.get_pretty_string() + "[/color], "
		else:
			string += effect.get_pretty_string() + ", "

	if string.ends_with(", "):
		string = string.rstrip(", ")
	if stats.effect_source.status_effects.is_empty():
		string = ""

	return string

func _get_charge_status_effects(stats: ItemResource) -> String:
	if stats is not MeleeWeaponResource:
		return ""
	elif not stats.can_do_charge_use:
		return ""

	var string: String = "CHRG EFFECTS:" + GlobalData.invis_char

	for effect: StatusEffect in stats.charge_effect_source.status_effects:
		if effect not in stats.original_charge_status_effects:
			string += "[color=Lawngreen]" + effect.get_pretty_string() + "[/color], "
		else:
			string += effect.get_pretty_string() + ", "

	if string.ends_with(", "):
		string = string.rstrip(", ")
	if stats.charge_effect_source.status_effects.is_empty():
		string = ""

	return string

func _get_sum(stats: ItemResource, list: Array[String], up_is_good: bool, suffix: String = "",
				mult: float = 1.0) -> String:
	var sum: float = 0
	var original_sum: float = 0

	for stat: String in list:
		sum += stats.get_nested_stat(stat, false)
		original_sum += stats.get_nested_stat(stat, true)

	sum *= mult
	original_sum *= mult

	var arrow: String = ""
	if (sum > original_sum) and up_is_good:
		arrow = up_green
	elif (sum > original_sum) and not up_is_good:
		arrow = up_red
	elif (sum < original_sum) and up_is_good:
		arrow = down_red
	elif (sum < original_sum) and not up_is_good:
		arrow = down_green

	var str_sum: String = str(snapped(sum, 0.001))
	if str_sum.ends_with(".0"):
		str_sum = str_sum.replace(".0", "")
	return str_sum + suffix + arrow
