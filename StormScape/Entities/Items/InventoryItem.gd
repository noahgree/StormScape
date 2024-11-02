extends RefCounted
class_name InventoryItem

var stats: ItemResource ## The resource driving the stats and type of item this is.
var quantity: int = 1 ## The quantity associated with the inventory item.


## Used when calling InventoryItem.new() to be able to pass in stats and a quantity.
func _init(item_stats: ItemResource, item_quantity: int = 1) -> void:
	self.stats = item_stats
	self.quantity = item_quantity

## Custom print logic for determining more about the item that just a randomly assigned ID.
func _to_string() -> String:
	return "(" + str(quantity) + ") " + str(GlobalData.ItemRarity.keys()[stats.rarity]) + "_" + stats.name

## Intended to be overridden by all subclasses in order to determine what to do when used.
func use_item() -> void:
	pass
