extends Resource
class_name InvItemResource
## An item resource with an associated quantity.

@export var stats: ItemResource = null ## The resource driving the stats and type of item this is.
@export var quantity: int = 1 ## The quantity associated with the inventory item.


## Used when calling InvItemResource.new() to be able to pass in stats and a quantity.
## The placeholder parameter determines if this resource needs its mod caches set up. If this item is being used
## as a preview or just for its image and will not be needing modded stats, mark placeholder as true.
func _init(item_stats: ItemResource = null, item_quantity: int = 1, placeholder: bool = false) -> void:
	if item_stats == null:
		self.stats = item_stats
	else:
		self.stats = item_stats.duplicate_with_suid()

	self.quantity = item_quantity

	if not placeholder:
		if stats is ProjWeaponResource:
			if stats.s_mods.base_values.is_empty(): # Otherwise it undoes any changes to values made my mods
				InitializationHelpers.initialize_proj_wpn_stats_resource(stats)
		elif stats is MeleeWeaponResource:
			if stats.s_mods.base_values.is_empty():
				InitializationHelpers.initialize_melee_wpn_stats_resource(stats)

## Triggers the session uid generator to give the stats for this inv item a new suid.
func assign_unique_suid() -> InvItemResource:
	stats.session_uid = 0
	return self

## Custom print logic for determining more about the item that just a randomly assigned ID.
func _to_string() -> String:
	return "(" + str(quantity) + ") " + str(Globals.ItemRarity.keys()[stats.rarity]) + "_" + stats.name
