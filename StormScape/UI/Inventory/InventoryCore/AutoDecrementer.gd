extends Node
class_name AutoDecrementer
## Manages entity-specific item cooldowns, warmups, blooming, overheating, and recharging via item identifiers.

signal cooldown_ended(item_id: StringName, cooldown_title: String) ## Emitted when any cooldown ends.
signal overheat_empty(item_id: StringName) ## Emitted when any overheat reaches 0 and is removed.
signal recharge_completed(item_id: StringName) ## Emitted when any recharge completes.

var cooldowns: Dictionary[StringName, Array] = {} ## Represents any active cooldowns where the key is an item's id and the value is an array with the following: [remaining_cooldown, original_cooldown_duration, cooldown_source]
var warmups: Dictionary[StringName, Array] = {} ## Represents any active warmups where the key is an item's id and the value is an array with the following: [current_warmup_value, decrease_rate_curve, decrease_delay_counter]
var blooms: Dictionary[StringName, Array] = {} ## Represents any active blooms where the key is an item's id and the value is an array with the following: [current_bloom_value, decrease_rate_curve, decrease_delay_counter]
var overheats: Dictionary[StringName, Array] = {} ## Represents any active overheats where the key is an item's id and the value is an array with the following: [current_overheat_progress, decrease_rate_curve, overheat_delay_counter]
var recharges: Dictionary[StringName, Array] = {} ## Represents any active recharges where the key is an item's id and the value is an array with the following: [current_recharge_progress, item_stats, recharge_delay_counter]
var owning_entity_is_player: bool = false ## When true, the entity owning the inv this script operates on is a Player.
var inv: InventoryResource ## The inventory that controls this auto decrementer.


func process(delta: float) -> void:
	_update_cooldowns(delta)
	_update_warmups(delta)
	_update_blooms(delta)
	_update_overheats(delta)
	_update_recharges(delta)

#region Cooldowns
## Adds a cooldown to the dictionary.
func add_cooldown(item_id: StringName, duration: float, title: String = "default") -> void:
	cooldowns[item_id] = [duration, duration, title]

	if owning_entity_is_player:
		Globals.player_node.hotbar_ui.update_hotbar_tint_progresses()

## Called every frame to update each cooldown value.
func _update_cooldowns(delta: float) -> void:
	var to_remove: Array[Array] = []
	for item_id: StringName in cooldowns.keys():
		cooldowns[item_id][0] -= delta
		if cooldowns[item_id][0] <= 0:
			to_remove.append([item_id, cooldowns[item_id][2]])

	for item: Array in to_remove:
		cooldowns.erase(item[0])
		cooldown_ended.emit(item[0], item[1])

## Returns a positive float representing the remaining cooldown or 0 if one does not exist.
func get_cooldown(item_id: StringName) -> float:
	return cooldowns.get(item_id, [0, 0, "default"])[0]

## Returns a string representing the cooldown source title if one exists, otherwise it returns a string of "null".
func get_cooldown_source_title(item_id: StringName) -> String:
	return cooldowns.get(item_id, [0, 0, "null"])[2]

## Returns a positive float representing the original duration of an active cooldown or 0 if it does not exist.
func get_original_cooldown(item_id: StringName) -> float:
	return cooldowns.get(item_id, [0, 0])[1]
#endregion

#region Warmups
## Adds a warmup to the dictionary.
func add_warmup(item_id: StringName, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	if item_id in warmups:
		warmups[item_id] = [min(1, warmups[item_id][0] + amount), decrease_rate, decrease_delay]
	else:
		warmups[item_id] = [min(1, amount), decrease_rate, decrease_delay]

## Called every frame to update each warmup value and its potential delay counter.
func _update_warmups(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in warmups.keys():
		var current: Array = warmups[item_id]
		if current[2] <= 0:
			warmups[item_id][0] -= delta * max(0.01, current[1].sample_baked(current[0]))
		else:
			warmups[item_id][2] -= delta

		if warmups[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		warmups.erase(item_id)

## Returns a positive float representing the current warmup value or 0 if one does not exist.
func get_warmup(item_id: StringName) -> float:
	return warmups.get(item_id, [0, null, 0])[0]
#endregion

#region Bloom
## Adds a bloom to the dictionary.
func add_bloom(item_id: StringName, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	if item_id in blooms:
		blooms[item_id] = [min(1, blooms[item_id][0] + amount), decrease_rate, decrease_delay]
	else:
		blooms[item_id] = [min(1, amount), decrease_rate, decrease_delay]

## Called every frame to update each bloom value and its potential delay counter.
func _update_blooms(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in blooms.keys():
		var current: Array = blooms[item_id]
		if current[2] <= 0:
			blooms[item_id][0] -= delta * max(0.01, current[1].sample_baked(current[0]))
		else:
			blooms[item_id][2] -= delta

		if blooms[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		blooms.erase(item_id)

## Returns a positive float representing the current bloom value or 0 if one does not exist.
func get_bloom(item_id: StringName) -> float:
	return blooms.get(item_id, [0, null, 0])[0]
#endregion

#region Overheats
## Adds a overheat to the dictionary.
func add_overheat(item_id: StringName, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	if item_id in overheats:
		overheats[item_id] = [min(1, overheats[item_id][0] + amount), decrease_rate, decrease_delay]
	else:
		overheats[item_id] = [min(1, amount), decrease_rate, decrease_delay]

## Called every frame to update each overheat value and its potential delay counter.
func _update_overheats(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in overheats.keys():
		var current: Array = overheats[item_id]
		if current[2] <= 0:
			overheats[item_id][0] -= delta * max(0.01, current[1].sample_baked(current[0]))
		else:
			overheats[item_id][2] -= delta

		if overheats[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		overheats.erase(item_id)
		overheat_empty.emit(item_id)

## Returns a positive float representing the current overheat value or 0 if one does not exist.
func get_overheat(item_id: StringName) -> float:
	return overheats.get(item_id, [0, null, 0])[0]
#endregion

#region Recharges
## Adds a recharge request to the dictionary.
func request_recharge(item_id: StringName, stats: ProjWeaponResource) -> void:
	if item_id in recharges:
		recharges[item_id] = [recharges[item_id][0], stats, 0]
	else:
		recharges[item_id] = [stats.s_mods.get_stat("auto_ammo_interval"), stats, 0]

## Adds a delay to the recharge.
func update_recharge_delay(item_id: StringName, delay_duration: float) -> void:
	if item_id in recharges:
		recharges[item_id][2] = delay_duration

## Called every frame to update each recharge value and its potential delay counter.
func _update_recharges(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in recharges.keys():
		var current: Array = recharges[item_id]
		if current[2] <= 0:
			recharges[item_id][0] -= delta
		else:
			recharges[item_id][2] -= delta

		if recharges[item_id][0] <= 0:
			if is_instance_valid(current[1]):
				var mag_size: int = current[1].s_mods.get_stat("mag_size")
				var auto_ammo_count: int = int(current[1].s_mods.get_stat("auto_ammo_count"))
				if current[1].recharge_uses_inv:
					var ammo_needed: int = min(mag_size - current[1].ammo_in_mag, auto_ammo_count)
					var retrieved_ammo: int = inv.get_more_ammo(ammo_needed, true, current[1].ammo_type)
					current[1].ammo_in_mag += retrieved_ammo
					if retrieved_ammo == 0:
						to_remove.append(item_id)
				else:
					current[1].ammo_in_mag = min(mag_size, current[1].ammo_in_mag + auto_ammo_count)
				recharge_completed.emit(item_id)

				if current[1].ammo_in_mag < mag_size:
					recharges[item_id][0] = current[1].s_mods.get_stat("auto_ammo_interval")
				else:
					to_remove.append(item_id)
			else:
				to_remove.append(item_id)

	for item_id: StringName in to_remove:
		recharges.erase(item_id)
		recharge_completed.emit(item_id)
#endregion
