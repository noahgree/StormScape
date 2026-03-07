@icon("res://Utilities/Debug/EditorIcons/dh_handler.svg")
extends Node
class_name DHHandler
## DH stands for "damage and healing". This handles applying damage and healing in different ways.

enum Type { DAMAGE, HEALING } ## For differentiating which we are working on when passing values around methods.

@onready var affected_entity: Entity = owner ## The entity affected by this dh handler.
@onready var hp_component: HPComponent = owner.hp_component ## The hp component to be affected by the incoming amounts.

var actives: Dictionary[Array, Dictionary] = {} ## The active effect over time instances running on this node. { [condition_id, source_type] : { eoti_uid : eoti } }.
var actives_by_id: Dictionary[Condition.ID, Dictionary] ## Another way of storing the active effect over time instances. { condition_id : { source_type : [eoti_uid] } }.


func _ready() -> void:
	set_process(false) # Wait until we have an active EOTI to start processing.

#region Instant Amounts
func handle_instant_amount(type: Type, popup_type: HPComponent.POPUP_TYPE, esi: ESI) -> int:
	var amount: int = 0
	var is_crit: bool = false
	if type == Type.DAMAGE:
		# --- Base Damage ---
		var base_damage: int = ceili(esi.get_stat(&"base_damage"))
		if base_damage == 0:
			return 0

		# --- Adjustments from Resistances, Weaknesses, and Affinities ---
		amount = _apply_condition_adjustments(base_damage, esi)

		# --- Adjustment from Critical Hits ---
		var crit_results: Array = _apply_crit_calculations(amount, esi)
		is_crit = crit_results[1]
		amount = crit_results[0]

		# --- Adjust for Level Scaling, Armor, and Object Mults ---
		amount = _apply_level_scaling(amount, esi, Type.DAMAGE)
		amount = _apply_armor_blocking(amount, esi)
		amount = _apply_object_scaling(amount, esi)
	else:
		# --- Base Healing ---
		var base_healing: int = ceili(esi.get_stat(&"base_healing"))
		if base_healing == 0:
			return 0

		# --- Adjustments from Resistances, Weaknesses, and Affinities ---
		amount = _apply_condition_adjustments(base_healing, esi)

		# --- Adjust for Level Scaling ---
		amount = _apply_level_scaling(amount, esi, Type.HEALING)

	# --- Get XP to Return ---
	var xp_gain: int = _calculate_resulting_xp(amount)
	popup_type = popup_type if not is_crit else HPComponent.POPUP_TYPE.CRIT_DAMAGE

	# --- Adjustments for Overall Dmg & Heal Resistance & Weakness ---
	amount = _apply_final_adjustments(amount, type)

	# --- Sending Final Amount & Returning XP ---
	send_handled_amount(type, amount, popup_type, esi)
	return xp_gain

func _apply_condition_adjustments(amount: int, esi: ESI) -> int:
	var inc_factor: float
	var dec_factor: float
	match esi.source_condition.id:
		Condition.ID.BURNING:
			inc_factor = affected_entity.sc.get_stat(&"burning_weakness")
			dec_factor = affected_entity.sc.get_stat(&"burning_resistance")
		Condition.ID.FROSTBITE:
			inc_factor = affected_entity.sc.get_stat(&"frostbite_weakness")
			dec_factor = affected_entity.sc.get_stat(&"frostbite_resistance")
		Condition.ID.POISON:
			inc_factor = affected_entity.sc.get_stat(&"poison_weakness")
			dec_factor = affected_entity.sc.get_stat(&"poison_resistance")
		Condition.ID.STORM_SYNDROME:
			inc_factor = affected_entity.sc.get_stat(&"storm_syndrome_weakness")
			dec_factor = affected_entity.sc.get_stat(&"storm_syndrome_resistance")
		Condition.ID.REGEN:
			inc_factor = affected_entity.sc.get_stat(&"heal_affinity")
			dec_factor = affected_entity.sc.get_stat(&"heal_reduction")

	var multiplier: float = 1.0 + (inc_factor / 100.0) - (dec_factor / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)
	return max(0, amount * multiplier)

func _apply_crit_calculations(amount: int, esi: ESI) -> Array:
	var is_crit: bool = (randf_range(0, 100) <= esi.get_stat(&"crit_chance")) and affected_entity.esi_receiver.can_be_crit
	if not is_crit:
		return [amount, false]
	return [round(amount * esi.get_stat(&"crit_multiplier")), true]

func _apply_level_scaling(amount: int, esi: ESI, type: Type) -> int:
	var level_mult: float = 1.0
	if type == Type.DAMAGE:
		level_mult = ((floori(esi.source_ii_lvl / 10.0) * esi.get_stat(&"lvl_dmg_scalar")) / 100.0) + 1
	else:
		level_mult = ((floori(esi.source_ii_lvl / 10.0) * esi.get_stat(&"lvl_heal_scalar")) / 100.0) + 1
	return ceili(amount * level_mult)

func _apply_armor_blocking(amount: int, esi: ESI) -> int:
	var armor_block_percent: int = max(0, hp_component.armor - esi.get_stat(&"armor_penetration"))
	return max(0, round(amount * (1 - (float(armor_block_percent) / 100))))

func _apply_object_scaling(amount: int, esi: ESI) -> int:
	if not affected_entity.is_object:
		return amount
	return int(amount * esi.get_stat(&"object_damage_mult"))

func _calculate_resulting_xp(amount: int) -> int:
	if amount >= (affected_entity.hp_component.health + affected_entity.hp_component.shield):
		return (amount + WeaponII.LARGE_XP)
	return amount

func _apply_final_adjustments(amount: int, type: Type) -> int:
	if type == Type.DAMAGE:
		var dmg_weakness: float = affected_entity.sc.get_stat(&"dmg_weakness")
		var dmg_resistance: float = affected_entity.sc.get_stat(&"dmg_resistance")
		var multiplier: float = 1.0 + (dmg_weakness / 100.0) - (dmg_resistance / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)
		return max(0, amount * multiplier)
	else:
		var heal_affinity: float = affected_entity.sc.get_stat(&"heal_affinity")
		var heal_reduction: float = affected_entity.sc.get_stat(&"heal_reduction")
		var multiplier: float = 1.0 + (heal_affinity / 100.0) - (heal_reduction / 100.0)
		multiplier = clamp(multiplier, 0.0, 2.0)
		return max(0, amount * multiplier)
#endregion


#region Amounts Over Time
func handle_eoti(eoti: EOTI) -> void:
	eoti.uid = UIDHelper.generate_eoti_uid()
	eoti.all_ticks_completed.connect(_remove_eoti_from_actives)

	var key: Array = eoti.get_key()
	if eoti.source_condition.id in actives:
		actives[key][eoti.uid] = eoti
		if eoti.source_condition.source_type in actives_by_id[eoti.source_condition.id]:
			actives_by_id[eoti.source_condition.id][eoti.source_condition.source_type].append(eoti.uid)
		else:
			actives_by_id[eoti.source_condition.id][eoti.source_condition.source_type] = [eoti.uid]
	else:
		actives[key] = { eoti.uid : eoti }
		actives_by_id[eoti.source_condition.id] = { eoti.source_condition.source_type : [eoti.uid] }

	set_process(true)

func _remove_eoti_from_actives(condition_id: Condition.ID, source_type: Condition.SourceType,
								eoti_uid: int) -> void:
	var key: Array = [condition_id, source_type]
	if key not in actives:
		push_warning(affected_entity.name + " tried to remove an EOTI from the active EOTI tracker using a condition ID that was not even being tracked.")
		return

	actives[key].erase(eoti_uid)
	if actives[key].is_empty():
		actives.erase(key)
	actives_by_id[condition_id][source_type].erase(eoti_uid)
	if actives_by_id[condition_id][source_type].is_empty():
		actives_by_id[condition_id].erase(source_type)
	if actives_by_id[condition_id].is_empty():
		actives_by_id.erase(condition_id)

	if actives.is_empty():
		set_process(false)

func stop_eotis_for_condition_id(condition_id: Condition.ID) -> void:
	for source_type: Condition.SourceType in actives_by_id[condition_id]:
		for eoti_uid: int in actives_by_id[condition_id][source_type]:
			_remove_eoti_from_actives(condition_id, source_type, eoti_uid)

func stop_eotis_by_source_type(condition_id: Condition.ID, source_type: Condition.SourceType) -> void:
	for eoti_uid: int in actives.get([condition_id, source_type]):
		_remove_eoti_from_actives(condition_id, source_type, eoti_uid)

func _process(delta: float) -> void:
	for eoti_key: Array in actives:
		for eoti_uid: int in actives[eoti_key]:
			actives[eoti_key][eoti_uid].process(delta)
#endregion


## Sends the affected entity's hp component the final amount values based on what stats the amount was
## allowed to affect.
func send_handled_amount(type: Type, amount: int, popup_type: HPComponent.POPUP_TYPE, esi: ESI) -> void:
	if type == Type.DAMAGE:
		_handle_life_steal(amount, esi)
		hp_component.change_by_dh_type(-amount, popup_type, esi.es.dmg_affected_stats, esi.multishot_id)
	else:
		hp_component.change_by_dh_type(amount, popup_type, esi.es.heal_affected_stats, esi.multishot_id)

	affected_entity.sprite.start_hitflash(esi.es.hit_flash_color, false)

## Handles a life steal interaction, passing the specified percentage of damage dealt back to the source
## entity as healing. Adjusts for life steal weakness and resistance.
func _handle_life_steal(damage_amount: int, esi: ESI) -> void:
	# Skip if source no longer exists and don't allow life steal on something that has infinite HP
	if (esi.source_entity == null) or (affected_entity.hp_component.infinte_hp):
		return

	var ls_condition_index: int = esi.conditions.find(LifeStealStats)
	if ls_condition_index == -1:
		return
	var ls_condition: LifeStealStats = esi.conditions.get(ls_condition_index)

	var self_hp_total: int = affected_entity.hp_component.health + affected_entity.hp_component.shield
	var steal_amount: int = int(floor(min(self_hp_total, damage_amount) * (ls_condition.dmg_steal_pct / 100.0)))

	var ls_weakness: float = affected_entity.sc.get_stat(&"life_steal_weakness")
	var ls_resistance: float = affected_entity.sc.get_stat(&"life_steal_resistance")

	var multiplier: float = 1.0 + (ls_weakness / 100.0) - (ls_resistance / 100.0)
	multiplier = clamp(multiplier, 0.0, 2.0)

	var clamped_steal_amount: int = max(1, roundi(steal_amount * multiplier))

	esi.source_entity.hp_component.change_by_dh_type(clamped_steal_amount, HPComponent.POPUP_TYPE.LIFE_STEAL, Globals.DHTypes.HEALTH_THEN_SHIELD)
