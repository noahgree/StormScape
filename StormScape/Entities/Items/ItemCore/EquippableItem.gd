extends Node2D
class_name EquippableItem
## The base class for all items that can be used by the HandsComponent. In order to be equipped and shown on screen in
## some place other than the inventory, the item resource must have an associated equippable item scene.

@export var stats: ItemResource = null: set = _set_stats ## The resource driving the stats and type of item. Do not set in editor, as this is automatically set on item creation via a static method.

var source_slot: Slot ## The slot this equippable item is in whilst equipped.
var source_entity: PhysicsBody2D ## The entity that is holding the equippable item.


## Creates an equippable item to be used via the slot it is currently in.
static func create_from_slot(item_source_slot: Slot) -> EquippableItem:
	var item: EquippableItem = item_source_slot.item.stats.item_scene.instantiate()
	item.source_slot = item_source_slot
	item.stats = item_source_slot.item.stats
	item.source_entity = item_source_slot.synced_inv.get_parent()
	return item

## Sets the item stats when changed. Can be overridden by child classes to do specific things on change.
func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats.duplicate()
	source_slot.synced_inv.inv[source_slot.index].stats = stats
	source_slot.item.stats = stats

func _ready() -> void:
	_set_stats(stats)
	add_to_group("has_save_logic")

## Intended to be overridden by child classes in order to specify what to do when this item is used.
func activate() -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is used after a hold click.
func hold_activate(_hold_time: float) -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is used after a released hold click.
func release_hold_activate(_hold_time: float) -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is equipped.
func enter() -> void:
	pass

## Intended to be overridden by child classes in order to specify what to do when this item is unequipped.
func exit() -> void:
	pass
