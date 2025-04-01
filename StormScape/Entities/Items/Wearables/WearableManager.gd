extends Node
class_name WearableManager
## A collection of static functions that handle adding, removing, and validating wearables on an entity.


## Checks the compatibility of a wearable with the entity who wants to equip it.
static func check_wearable_compatibility(entity: PhysicsBody2D, wearable: Wearable) -> bool:
	for wearable_entry: Dictionary in entity.wearables:
		if wearable_entry.values()[0] != null:
			if wearable_entry.keys()[0] in wearable.blocked_mutuals:
				return false

	return true

## Handles an incoming wearable, checking its compatibility and eventually adding it if it can.
static func handle_wearable(entity: PhysicsBody2D, wearable: Wearable, index: int) -> void:
	if not check_wearable_compatibility(entity, wearable):
		return

	add_wearable(entity, wearable, index)

## Adds a wwearable to the dictionary.
static func add_wearable(entity: PhysicsBody2D, wearable: Wearable, index: int) -> void:
	if DebugFlags.PrintFlags.wearable_changes:
		print_rich("-------[color=green]Adding[/color][b] " + str(wearable.name) + " (" + str(wearable.rarity) + ")[/b][color=gray] to " + entity.name + "-------")

	entity.wearables[index] = { wearable.id : wearable }

	for mod_resource: StatMod in wearable.stat_mods:
		entity.stats.add_mods([mod_resource] as Array[StatMod])

	if wearable.equipping_audio != "":
		AudioManager.play_sound(wearable.equipping_audio, AudioManager.SoundType.SFX_GLOBAL)

## Removes the wearable from the dictionary.
static func remove_wearable(entity: PhysicsBody2D, wearable: Wearable, index: int) -> void:
	if DebugFlags.PrintFlags.wearable_changes and WearableManager.has_wearable(entity, wearable.id):
		print_rich("-------[color=red]Removed[/color][b] " + str(wearable.name) + " (" + str(wearable.rarity) + ")[/b][color=gray] from " + entity.name + "-------")

	for mod_resource: StatMod in wearable.stat_mods:
		entity.stats.remove_mod(mod_resource.stat_id, mod_resource.mod_id)

	entity.wearables[index] = { "EmptySlot" : null }

## Checks to see if the entity has the passed in wearable already, regardless of level.
static func has_wearable(entity: PhysicsBody2D, wearable_id: StringName) -> bool:
	for wearable_entry: Dictionary in entity.wearables:
		if wearable_entry.values()[0] != null:
			if wearable_entry.keys()[0] == wearable_id:
				return true
	return false
