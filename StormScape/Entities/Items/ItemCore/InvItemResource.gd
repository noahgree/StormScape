extends Resource
class_name InvItemResource
## An item resource with an associated quantity.

@export var stats: ItemResource = null ## The resource driving the stats and type of item this is.
@export var quantity: int = 1 ## The quantity associated with the inventory item.


## Used when calling InvItemResource.new() to be able to pass in stats and a quantity.
## The placeholder parameter determines if this resource needs its mod caches set up. If this item is being used
## as a preview or just for its image and will not be needing modded stats, mark placeholder as true.
func _init(item_stats: ItemResource = null, item_quantity: int = 1, placeholder: bool = false) -> void:
	self.stats = item_stats.duplicate_with_suid() if item_stats != null else item_stats # Otherwise we won't have uniqueness until the stats are part of a physical equipped item and set then
	self.quantity = item_quantity

	if not placeholder:
		if stats is ProjWeaponResource:
			if stats.s_mods.base_values.is_empty(): # Otherwise it undoes any changes to values made my mods
				ProjectileWeapon.initialize_stats_resource(stats)
		elif stats is MeleeWeaponResource:
			if stats.s_mods.base_values.is_empty():
				MeleeWeapon.initialize_stats_resource(stats)

## Custom print logic for determining more about the item that just a randomly assigned ID.
func _to_string() -> String:
	return "(" + str(quantity) + ") " + str(Globals.ItemRarity.keys()[stats.rarity]) + "_" + stats.name
