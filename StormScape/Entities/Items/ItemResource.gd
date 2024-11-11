extends Resource
class_name ItemResource

@export_group("Item Details")
@export var id: String ## The unique identifier for the item.
@export var name: String ## The item's string name.
@export var icon: Texture2D ## The inventory representation of the item.
@export var thumbnail: Texture2D ## The physical representation of the item.
@export var item_type: GlobalData.ItemType = GlobalData.ItemType.CONSUMABLE ## The type that this item is.
@export var rarity: GlobalData.ItemRarity = GlobalData.ItemRarity.COMMON ## The rarity of this item.
@export var weight: int = 0 ## If greater than 0, holding this item in the main hand will affect stats like speed.
@export var stack_size: int = 1 ## The max amount that can stack in one inventory slot.
@export var auto_pickup: bool = false ## Whether this item should automatically be picked up when run over.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var pickup_radius: int = 4 ## The radius at which the item can be detected for pickup.
@export_multiline var info: String ## The multiline information about this item.

## The custom string representation of this item resource.
func _to_string() -> String:
	return str(GlobalData.ItemType.keys()[item_type]) + ": " + str(GlobalData.ItemRarity.keys()[rarity]) + "_" + name

## Whether the item is the same as another item when called externally to compare.
func is_same_as(other_item: ItemResource) -> bool:
	return (name == other_item.name) and (item_type == other_item.item_type) and (rarity == other_item.rarity)
