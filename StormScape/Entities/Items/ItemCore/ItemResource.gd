extends Resource
class_name ItemResource
## The top level resource class for all items in the game.

@export var id: String ## The unique identifier for the item.
@export var name: String ## The item's string name.
@export var tags: Array[StringName] = [] ## The set of tags that are checked against when this item is potentially used for crafting.
@export var item_type: GlobalData.ItemType = GlobalData.ItemType.CONSUMABLE ## The type that this item is.
@export var rarity: GlobalData.ItemRarity = GlobalData.ItemRarity.COMMON ## The rarity of this item.
@export var stack_size: int = 1 ## The max amount that can stack in one inventory slot.
@export var auto_pickup: bool = false ## Whether this item should automatically be picked up when run over.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var pickup_radius: int = 4 ## The radius at which the item can be detected for pickup.
@export_multiline var info: String ## The multiline information about this item.

@export_group("Visuals")
@export var ground_icon: Texture2D ## The on-ground representation of the item.
@export var in_hand_icon: Texture2D ## The physical representation of the item.
@export var inv_icon: Texture2D ## The inventordy representation of the item.
@export var inv_icon_offset: Vector2 = Vector2.ZERO ## How much to offset the inv icon in a slot.
@export var inv_icon_scale: Vector2 = Vector2.ONE ## How much to scale the inv icon in a slot.
@export_range(-360, 360, 1, "suffix:degrees") var inv_icon_rotation: float = 0 ## How much to rotate the inv icon in a slot.
@export_subgroup("Cursors")
@export var cursors: SpriteFrames ## The cursors that can show when this item is equipped. Must be a SpriteFrames resource. Can have additional cursor animations within the resource to change depending on scenario (such as a different reloading cursor).

@export_group("Crafting")
@export var recipe: Array[CraftingIngredient] = [] ## The items & quantities required to craft an instance of this item.
@export var output_quantity: int = 1 ## The number of resulting instances of this item that spawn when crafted.
@export var recipe_unlocked: bool = true ## A flag to determine whether or not this item can be crafted. True by default.

@export_category("Equippable Item")
@export var item_scene: PackedScene = null ## The equippable representation of this item. If left null, this item cannot be equipped.
@export_range(0, 1, 0.001) var rotation_lerping: float = 0.1 ## How fast the rotation lerping should be while holding this item.
@export var holding_offset: Vector2 = Vector2.ZERO ## The offset for placing the icon of the sprite in the entity's hand.
@export_custom(PROPERTY_HINT_NONE, "suffix:degrees") var holding_degrees: float = 0 ## The rotation offset for holding the thumnbail sprite in the entity's hand.

@export_group("Hand Positioning")
@export var is_gripped_by_one_hand: bool = true ## Whether or not this item should only have one hand shown gripping it.
@export var draw_off_hand: bool = false ## When true, the hands component will draw the off hand for it as well (hiding the idly animated off hand). This only applies when is_gripped_by_one_hand is false.
@export var draw_off_hand_offset: Vector2 = Vector2.ZERO ## The offset for placing the off hand sprite when holding this item, assuming that draw_off_hand is true and is_gripped_by_one_hand is false.
@export var main_hand_offset: Vector2 = Vector2.ZERO ## The offset for placing the main hand sprite when holding this item.

@export_group("Cooldown Details")
@export var cooldowns_per_suid: bool = true ## When true, cooldowns will be based on instances of this item as they were picked up or added to the inventory. They will not be shared amongst all items of the same base id.
@export var shown_cooldown_fills: Array[String] = [] ## Which cooldown source's can show the vertical fill on the slot when the player invokes a cooldown on this item.
@export var show_cursor_cooldown: bool = false ## When true, the cursor will vertically fill for any cooldown in the array above instead of ever vertically filling for reloads in progress.


# Unique Properties #
@export_storage var session_uid: int: ## The unique id for this resource instance that is relevant only for the current game load.
	## Sets the session uid based on the new value. If it is negative, it means we want to keep the old suid and can simply
	## absolute value it and decrement the UIDHelper's var since it will have already triggered the increment once before on the
	## duplication call. Otherwise, we generate a new one.
	set(new_value):
		if new_value >= 0:
			session_uid = UIDHelper.generate_session_uid()
		else:
			session_uid = abs(new_value)
			UIDHelper.session_uid_counter -= 1


## The custom string representation of this item resource.
func _to_string() -> String:
	return str(GlobalData.ItemType.keys()[item_type]) + ": " + get_rarity_string() + "_" + name

## Returns the unique identifier used to distinguish the recipe of this item.
func get_recipe_id() -> StringName:
	return StringName(id)

## Returns the cooldown id based on how cooldowns are determined for this item.
func get_cooldown_id() -> StringName:
	if not cooldowns_per_suid:
		return StringName(id)
	else:
		return StringName(str(session_uid))

## Returns the string title of the rarity rather than just the enum integer value.
func get_rarity_string() -> String:
	return str(GlobalData.ItemRarity.keys()[rarity])

## Returns the string title of the item type rather than just the enum integer value.
func get_item_type_string() -> String:
	return str(GlobalData.ItemType.keys()[item_type])

## Whether the item is the same as another item when called externally to compare.
func is_same_as(other_item: ItemResource) -> bool:
	return (str(self) == str(other_item))

## Custom duplication method that passes the old session_uid as a negative in order to trick the setter
## function to keeping it.
func duplicate_with_suid(duplicate_subresources: bool = false) -> ItemResource:
	var duplicated: ItemResource = self.duplicate(duplicate_subresources)
	duplicated.session_uid = -session_uid
	return duplicated
