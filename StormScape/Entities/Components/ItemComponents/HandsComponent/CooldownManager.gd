extends Node
## Manages entity-specific item cooldowns via item identifiers.

signal cooldown_ended(item_id: int) ## Emitted when any cooldown ends, but contains the associated item id to check against.

var cooldowns: Dictionary = {} ## A dictionary representing any active cooldowns where the key is an item's id and the value is an array where the element 0 is the cooldown remaining and element 1 is the original cooldown duration.


func _process(delta: float) -> void:
	_update_cooldowns(delta)

## Adds a cooldown to the dictionary.
func add_cooldown(item_id: String, duration: float, initial_duration_override: float = -1) -> void:
	set_process(true)
	if item_id in cooldowns:
		cooldowns[item_id][0] = duration
	else:
		cooldowns[item_id] = [duration, duration if initial_duration_override == -1 else initial_duration_override]

	if get_parent().entity is Player:
		GlobalData.player_node.hotbar_ui.update_hotbar_tint_progresses()

## Called every frame to update each cooldown value.
func _update_cooldowns(delta: float) -> void:
	var to_remove: Array = []
	for item_id: String in cooldowns.keys():
		cooldowns[item_id][0] -= delta # Only decrementing the cooldown index, leaving the original duration in index 1 alone
		if cooldowns[item_id][0] <= 0:
			to_remove.append(item_id)

	for item_id: String in to_remove:
		cooldowns.erase(item_id)
		cooldown_ended.emit(item_id)

	if cooldowns.is_empty():
		set_process(false)

## Returns a positive float representing the remaining cooldown or 0 if one does not exist.
func get_cooldown(item_id: String) -> float:
	return cooldowns.get(item_id, [0, 0])[0]

## Returns a positive float representing the original duration of an active cooldown or 0 if it does not exist.
func get_original_cooldown(item_id: String) -> float:
	return cooldowns.get(item_id, [0, 0])[1]
