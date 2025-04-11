extends Node
class_name AutoDecrementer
## Manages entity-specific item cooldowns, warmups, blooming, overheating, and recharging via item identifiers.

var cooldowns: Dictionary[StringName, Dictionary] = {} ## Represents any active cooldowns where the key is an item's id.
var warmups: Dictionary[StringName, Dictionary] = {} ## Represents any active warmups where the key is an item's id.
var blooms: Dictionary[StringName, Dictionary] = {} ## Represents any active blooms where the key is an item's id.
var overheats: Dictionary[StringName, Dictionary] = {} ## Represents any active overheats where the key is an item's id.
var recharges: Dictionary[StringName, Dictionary] = {} ## Represents any active recharges where the key is an item's id.
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
func add_cooldown(item_id: StringName, duration: float, finished_callable: Callable, title: String = "default") -> void:
	cooldowns[item_id] = {
		&"duration" : duration,
		&"original_duration" : duration,
		&"finished_callable" : finished_callable,
		&"source_title" : title
	}

	if owning_entity_is_player:
		Globals.player_node.hotbar_ui.update_hotbar_tint_progresses()

## Called every frame to update each cooldown value.
func _update_cooldowns(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in cooldowns.keys():
		var current: Dictionary = cooldowns[item_id]
		current.duration -= delta
		if current.duration <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		var finished_callable: Callable = cooldowns[item_id].finished_callable
		if finished_callable.is_valid():
			finished_callable.call(cooldowns[item_id].source_title)
		cooldowns.erase(item_id)

## Returns a positive float representing the remaining cooldown or 0 if one does not exist.
func get_cooldown(item_id: StringName) -> float:
	return cooldowns.get(item_id, {}).get(&"duration", 0)

## Returns a positive float representing the original duration of an active cooldown or 0 if it does not exist.
func get_original_cooldown(item_id: StringName) -> float:
	return cooldowns.get(item_id, {}).get(&"original_duration", 0)

## Returns a string representing the cooldown source title if one exists, otherwise it returns a string of "null".
func get_cooldown_source_title(item_id: StringName) -> String:
	return cooldowns.get(item_id, {}).get(&"source_title", "null")
#endregion

#region Warmups
## Adds a warmup to the dictionary.
func add_warmup(item_id: StringName, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	var new_value: float
	if item_id in warmups:
		new_value = min(1, warmups[item_id].warmup_value + amount)
	else:
		new_value = min(1, amount)

	warmups[item_id] = {
		&"warmup_value" : new_value,
		&"decrease_curve" : decrease_rate,
		&"decrease_delay" : decrease_delay
	}

## Called every frame to update each warmup value and its potential delay counter.
func _update_warmups(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in warmups.keys():
		var current: Dictionary = warmups[item_id]
		if current.decrease_delay <= 0:
			current.warmup_value -= delta * max(0.01, current.decrease_curve.sample_baked(current.warmup_value))
		else:
			current.decrease_delay -= delta

		if current.warmup_value <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		warmups.erase(item_id)

## Returns a positive float representing the current warmup value or 0 if one does not exist.
func get_warmup(item_id: StringName) -> float:
	return warmups.get(item_id, {}).get(&"warmup_value", 0)
#endregion

#region Bloom
## Adds a bloom to the dictionary.
func add_bloom(item_id: StringName, amount: float, decrease_rate: Curve, decrease_delay: float) -> void:
	var new_value: float
	if item_id in blooms:
		new_value = min(1, blooms[item_id].bloom_value + amount)
	else:
		new_value = min(1, amount)

	blooms[item_id] = {
		&"bloom_value" : new_value,
		&"decrease_curve" : decrease_rate,
		&"decrease_delay" : decrease_delay
	}

## Called every frame to update each bloom value and its potential delay counter.
func _update_blooms(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in blooms.keys():
		var current: Dictionary = blooms[item_id]
		if current.decrease_delay <= 0:
			current.bloom_value -= delta * max(0.01, current.decrease_curve.sample_baked(current.bloom_value))
		else:
			current.decrease_delay -= delta

		if current.bloom_value <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		blooms.erase(item_id)

## Returns a positive float representing the current bloom value or 0 if one does not exist.
func get_bloom(item_id: StringName) -> float:
	return blooms.get(item_id, {}).get(&"bloom_value", 0)
#endregion

#region Overheats
## Adds a overheat to the dictionary.
func add_overheat(item_id: StringName, amount: float, decrease_rate: Curve, decrease_delay: float,
					finished_callable: Callable) -> void:
	var new_value: float
	if item_id in overheats:
		new_value = min(1, overheats[item_id].progress + amount)
	else:
		min(1, amount)

	overheats[item_id] = {
		&"progress" : new_value,
		&"decrease_curve" : decrease_rate,
		&"decrease_delay" : decrease_delay,
		&"finished_callable" : finished_callable
	}

## Called every frame to update each overheat value and its potential delay counter.
func _update_overheats(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in overheats.keys():
		var current: Dictionary[StringName, Variant] = overheats[item_id]
		if current.decrease_delay <= 0:
			current.progress -= delta * max(0.01, current.decrease_curve.sample_baked(current.progress))
		else:
			current.decrease_delay -= delta

		if current.progress <= 0:
			to_remove.append(item_id)

	for item_id: StringName in to_remove:
		var finished_callable: Callable = overheats[item_id].finished_callable
		if finished_callable.is_valid():
			finished_callable.call()
		overheats.erase(item_id)

## Returns a positive float representing the current overheat value or 0 if one does not exist.
func get_overheat(item_id: StringName) -> float:
	return overheats.get(item_id, {}).get(&"progress", 0)
#endregion

#region Recharges
## Adds a recharge request to the dictionary.
func request_recharge(item_id: StringName, duration: float, finished_callable: Callable) -> void:
	if item_id not in recharges:
		recharges[item_id] = {
			&"progress" : duration,
			&"original_duration" : duration,
			&"decrease_delay" : 0,
			&"finished_callable" : finished_callable
		}

## Adds a delay to the recharge.
func update_recharge_delay(item_id: StringName, delay_duration: float) -> void:
	if item_id in recharges:
		recharges[item_id].decrease_delay = delay_duration

## Called every frame to update each recharge value and its potential delay counter.
func _update_recharges(delta: float) -> void:
	var to_remove: Array[StringName] = []
	for item_id: StringName in recharges.keys():
		var current: Dictionary = recharges[item_id]
		if current.decrease_delay <= 0:
			current.progress -= delta
		else:
			current.decrease_delay -= delta

		if current.progress <= 0:
			var finished_callable: Callable = current.finished_callable
			if finished_callable.is_valid():
				var is_full: bool = finished_callable.call()
				if is_full:
					to_remove.append(item_id)
				else:
					current.progress = current.original_duration
			else:
				to_remove.append(item_id)

	for item_id: StringName in to_remove:
		recharges.erase(item_id)

## Returns a positive float representing the current recharge progress or 0 if one does not exist.
func get_recharge(item_id: StringName) -> float:
	return recharges.get(item_id, {}).get(&"progress", 0)
#endregion
