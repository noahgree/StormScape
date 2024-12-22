extends Node
class_name AutoDecrementer
## Manages entity-specific item cooldowns, warmups, blooming, overheating, and recharging via item identifiers.

signal cooldown_ended(item_id: String) ## Emitted when any cooldown ends.
signal recharge_completed(item_id: String) ## Emitted when any recharge completes.

var cooldowns: Dictionary = {} ## Represents any active cooldowns where the key is an item's id and the value is an array with the following: [remaining_cooldown, original_cooldown_duration]
var warmups: Dictionary = {} ## Represents any active warmups where the key is an item's id and the value is an array with the following: [current_warmup_value, decrease_rate_curve, decrease_delay_counter]
var blooms: Dictionary = {} ## Represents any active blooms where the key is an item's id and the value is an array with the following: [current_bloom_value, decrease_rate_curve, decrease_delay_counter]
var overheats: Dictionary = {}
var recharges: Dictionary = {}
var owning_entity_is_player: bool = false ## When true, the entity owning the inv this script operates on is a Player.


#region Cooldowns
## Adds a cooldown to the dictionary.
func add_cooldown(item_id: String, duration: float, initial_duration_override: float = -1) -> void:
	if item_id in cooldowns:
		cooldowns[item_id][0] = duration
	else:
		cooldowns[item_id] = [duration, duration if initial_duration_override == -1 else initial_duration_override]

	if owning_entity_is_player:
		GlobalData.player_node.hotbar_ui.update_hotbar_tint_progresses()

## Called every frame to update each cooldown value.
func _update_cooldowns(delta: float) -> void:
	var to_remove: Array[String] = []
	for item_id: String in cooldowns.keys():
		cooldowns[item_id][0] -= delta
		if cooldowns[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: String in to_remove:
		cooldowns.erase(item_id)
		cooldown_ended.emit(item_id)

## Returns a positive float representing the remaining cooldown or 0 if one does not exist.
func get_cooldown(item_id: String) -> float:
	return cooldowns.get(item_id, [0, 0])[0]

## Returns a positive float representing the original duration of an active cooldown or 0 if it does not exist.
func get_original_cooldown(item_id: String) -> float:
	return cooldowns.get(item_id, [0, 0])[1]
#endregion

#region Warmups
## Adds a warmup to the dictionary.
func add_warmup(item_id: String, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	if item_id in warmups:
		warmups[item_id] = [min(1, warmups[item_id][0] + amount), decrease_rate, decrease_delay]
	else:
		warmups[item_id] = [min(1, amount), decrease_rate, decrease_delay]

## Called every frame to update each warmup value and its potential delay counter.
func _update_warmups(delta: float) -> void:
	var to_remove: Array[String] = []
	for item_id: String in warmups.keys():
		var current: Array = warmups[item_id]
		if current[2] <= 0:
			warmups[item_id][0] -= delta * max(0.01, current[1].sample_baked(current[0]))
		else:
			warmups[item_id][2] -= delta

		if warmups[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: String in to_remove:
		warmups.erase(item_id)

## Returns a positive float representing the current warmup value or 0 if one does not exist.
func get_warmup(item_id: String) -> float:
	return warmups.get(item_id, [0, null, 0])[0]
#endregion

#region Bloom
## Adds a bloom to the dictionary.
func add_bloom(item_id: String, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	if item_id in blooms:
		blooms[item_id] = [min(1, blooms[item_id][0] + amount), decrease_rate, decrease_delay]
	else:
		blooms[item_id] = [min(1, amount), decrease_rate, decrease_delay]

## Called every frame to update each bloom value and its potential delay counter.
func _update_blooms(delta: float) -> void:
	var to_remove: Array[String] = []
	for item_id: String in blooms.keys():
		var current: Array = blooms[item_id]
		if current[2] <= 0:
			blooms[item_id][0] -= delta * max(0.01, current[1].sample_baked(current[0]))
		else:
			blooms[item_id][2] -= delta

		if blooms[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: String in to_remove:
		blooms.erase(item_id)

## Returns a positive float representing the current bloom value or 0 if one does not exist.
func get_bloom(item_id: String) -> float:
	return blooms.get(item_id, [0, null, 0])[0]
#endregion

#region Overheats
func add_overheat(_item_id: String, _duration: float) -> void:
	pass

func _update_overheats(_delta: float) -> void:
	pass

func get_overheat(item_id: String) -> float:
	return overheats.get(item_id, [0, null, 0])[0]
#endregion

#region Recharges
## Adds a recharge request to the dictionary.
func request_recharge(item_id: String, duration: float) -> void:
	if item_id not in recharges:
		recharges[item_id] = [duration, duration, 0]

## Adds a delay to the recharge.
func update_recharge_delay(item_id: String, delay_duration: float) -> void:
	if item_id in recharges:
		recharges[item_id][0] = recharges[item_id][1]
		recharges[item_id][2] = delay_duration

## Called every frame to update each recharge value and its potential delay counter.
func _update_recharges(delta: float) -> void:
	var to_remove: Array[String] = []
	for item_id: String in recharges.keys():
		var current: Array = recharges[item_id]
		if current[2] <= 0:
			recharges[item_id][0] -= delta
		else:
			recharges[item_id][2] -= delta

		if recharges[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: String in to_remove:
		recharges.erase(item_id)
		recharge_completed.emit(item_id)
#endregion
