extends Node2D
class_name EquippableItem
## The base class for all items that can be used by the HandsComponent. In order to be equipped and shown on screen in
## some place other than the inventory, the item resource must have an associated equippable item scene.

@export var stats: ItemResource = null: set = _set_stats ## The resource driving the stats and type of item. Do not set in editor, as this is automatically set on item creation via a static method.
@export var is_gripped_by_one_hand: bool = true ## Whether or not this item should only have one hand shown gripping it.

var source_slot: Slot ## The slot this equippable item is in whilst equipped.
var source_entity: PhysicsBody2D ## The entity that is holding the equippable item.


## Creates an equippable item to be used via the slot it is currently in.
static func create_from_slot(item_source_slot: Slot) -> EquippableItem:
	var item: EquippableItem = item_source_slot.item.stats.item_scene.instantiate()
	item.stats = item_source_slot.item.stats
	item.source_slot = item_source_slot
	item.source_entity = item_source_slot.synced_inv.get_parent()
	return item

## Sets the item stats when changed. Can be overridden by child classes to do specific things on change.
func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats

func _ready() -> void:
	_set_stats(stats)

## Intended to be overridden by child classes in order to specify what to do when this item is used.
func activate() -> void:
	pass

func enter() -> void:
	pass

func exit() -> void:
	pass
