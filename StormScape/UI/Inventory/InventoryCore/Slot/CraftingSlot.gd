@tool
extends Slot
class_name CraftingSlot
## A child class of Slot that changes the conditions for which data can be dropped.

signal item_changed
signal output_drag_started

@export var is_output_slot: bool = false ## Whether or not this crafting slot is an output slot.

var just_crafted: bool = false ## Only true immediately after picking up the output from the output slot. If it gets dropped back into the output slot afterwards, this flag will be false again.


## Determines if the slot we are hovering over during a drag can accept drag data on mouse release.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data.item == null or not synced_inv or data.index == index or is_output_slot:
		return false
	if item == null:
		return true
	if item.stats.is_same_as(data.item.stats):
		if item.quantity >= item.stats.stack_size:
			return false
		else:
			return true
	else:
		if data.dragging_only_one or data.dragging_half_stack:
			return false
	return true


func _set_item(new_item: InvItemResource) -> void:
	super._set_item(new_item)
	item_changed.emit()

func _on_just_started_drag() -> void:
	if just_crafted and is_output_slot:
		output_drag_started.emit()
	just_crafted = false
