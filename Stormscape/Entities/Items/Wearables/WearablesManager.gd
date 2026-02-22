class_name WearablesManager
## A collection of static functions that handle adding, removing, and validating wearables on an entity.


## Checks the compatibility of a wearable with the entity who wants to equip it.
static func check_wearable_compatibility(entity: Entity, wearable_to_check: WearableStats) -> bool:
	for wearable_index: int in range(entity.current_wearables.size()):
		var wearable_id: StringName = entity.current_wearables[wearable_index]
		if (wearable_id != &"") and (wearable_id in wearable_to_check.blocked_mutuals):
			return false
	return true

## Handles an incoming wearable, checking its compatibility and eventually adding it if it can.
static func handle_wearable(entity: Entity, wearable: WearableStats, index: int) -> void:
	if not check_wearable_compatibility(entity, wearable):
		return

	for wearable_index: int in range(entity.current_wearables.size()):
		if wearable.id == entity.current_wearables[wearable_index]:
			remove_wearable(entity, wearable_index)
		elif wearable_index == index and entity.current_wearables[wearable_index] != &"":
			push_warning("\"" + entity.current_wearables[wearable_index] + "\" was already in wearable slot " + str(wearable_index) + " and will now be removed to make room for \"" + wearable.get_cache_key() + "\"")
			remove_wearable(entity, wearable_index)

	add_wearable(entity, wearable, index)

## Adds a wearable to the dictionary.
static func add_wearable(entity: Entity, wearable: WearableStats, index: int) -> void:
	# ----- Debug printouts -----
	if DebugFlags.wearable_changes:
		print_rich("-------[color=green]Adding[/color][b] " + str(wearable.name) + " (" + str(wearable.rarity) + ")[/b][color=gray] to " + entity.name + " (slot " + str(index) + ")" + "-------")

	# ----- Adding to the current wearables array -----
	entity.current_wearables[index] = StringName(wearable.get_cache_key())

	# ----- Updating the stat cache on the entity -----
	for mod_resource: StatMod in wearable.stat_mods:
		entity.stats.add_mods([mod_resource] as Array[StatMod])

	AudioManager.play_global(wearable.equipping_audio)

## Removes the wearable at the given index from the entity.
static func remove_wearable(entity: Entity, index: int) -> void:
	# ----- Ensuring the wearable exists -----
	var wearable_to_remove: WearableStats = Items.cached_items.get(entity.current_wearables[index], null)
	if wearable_to_remove == null:
		push_error("The wearable at index " + str(index) + " of " + entity.name + " could not be removed.")
		return

	# ----- Debug printouts -----
	if DebugFlags.wearable_changes and entity.has_wearable(wearable_to_remove.id, index):
		print_rich("-------[color=red]Removed[/color][b] " + str(wearable_to_remove.name) + " (" + str(wearable_to_remove.rarity) + ")[/b][color=gray] from " + entity.name + " (slot " + str(index) + ")" + "-------")

	# ----- Updating the stat cache on the entity -----
	for mod_resource: StatMod in wearable_to_remove.stat_mods:
		entity.stats.remove_mod(mod_resource.stat_id, mod_resource.mod_id)

	# ----- Removing from the current wearables array -----
	entity.current_wearables[index] = &""

	# ----- Playing removal audio -----
	AudioManager.play_global(wearable_to_remove.removal_audio)

## Removes all wearables from the entity.
static func removal_all_wearables(entity: Entity) -> void:
	for wearable_index: int in range(entity.current_wearables.size()):
		remove_wearable(entity, wearable_index)

## Adds all wearables in an entity's wearables array on to it. (i.e. adds all mods from them).
static func add_all_wearables_to_entity(entity: Entity) -> void:
	for wearable_index: int in range(entity.current_wearables.size()):
		if entity.current_wearables[wearable_index] != &"":
			var wearable: WearableStats = Items.cached_items.get(entity.current_wearables[wearable_index], null)
			remove_wearable(entity, wearable_index)
			if wearable:
				handle_wearable(entity, wearable, wearable_index)
			else:
				push_error("Adding all wearables to " + entity.name + " failed.")
