extends Resource
class_name ItemResource

@export_group("Item Details")
@export var id: String ## The unique identifier for the item.
@export var name: String ## The item's string name.
@export var tags: Array[String] = [] ## The set of tags that are checked against when this item is potentially used for crafting.
@export var icon: Texture2D ## The inventory representation of the item.
@export var thumbnail: Texture2D ## The physical representation of the item.
@export var item_type: GlobalData.ItemType = GlobalData.ItemType.CONSUMABLE ## The type that this item is.
@export var rarity: GlobalData.ItemRarity = GlobalData.ItemRarity.COMMON ## The rarity of this item.
@export var weight: int = 0 ## If greater than 0, holding this item in the main hand will affect stats like speed.
@export var stack_size: int = 1 ## The max amount that can stack in one inventory slot.
@export var auto_pickup: bool = false ## Whether this item should automatically be picked up when run over.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var pickup_radius: int = 4 ## The radius at which the item can be detected for pickup.
@export_multiline var info: String ## The multiline information about this item.

@export_group("Crafting")
@export var recipe: Array[CraftingIngredient] = [] ## The items & quantities required to craft an instance of this item.
@export var output_quantity: int = 1 ## The number of resulting instances of this item that spawn when crafted.

@export_group("Equippability Details")
@export var item_scene: PackedScene = null ## The equippable representation of this item.
@export_range(0, 1, 0.01) var rotation_lerping: float = 0.1 ## How fast the rotation lerping should be while holding this item.
@export var holding_offset: Vector2 = Vector2.ZERO ## The offset for placing the thumbnail of the sprite in the entity's hand.
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var holding_degrees: float = 0 ## The rotation offset for holding the thumnbail sprite in the entity's hand.
@export_subgroup("Manual Hands Positioning")
@export var is_gripped_by_one_hand: bool = true ## Whether or not this item should only have one hand shown gripping it.
@export var draw_off_hand: bool = false ## When true, the hands component will draw the off hand for it as well (hiding the idly animated off hand). This only applies when is_gripped_by_one_hand is false. Must have a Marker2D titled "OffHandLocation" in the item scene.
@export var draw_off_hand_offset: Vector2 = Vector2.ZERO ## The offset for placing the off hand sprite when holding this item, assuming that draw_off_hand is true and is_gripped_by_one_hand is false.
@export var main_hand_offset: Vector2 = Vector2.ZERO ## The offset for placing the main hand sprite when holding this item.


## The custom string representation of this item resource.
func _to_string() -> String:
	return str(GlobalData.ItemType.keys()[item_type]) + ": " + str(GlobalData.ItemRarity.keys()[rarity]) + "_" + name

## Whether the item is the same as another item when called externally to compare.
func is_same_as(other_item: ItemResource) -> bool:
	return (name == other_item.name) and (item_type == other_item.item_type) and (rarity == other_item.rarity)
