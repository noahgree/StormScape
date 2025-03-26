extends Slot
class_name CraftingSlot
## A child class of Slot that changes the conditions for which data can be dropped.

signal output_changed(is_craftable: bool)

@export var is_output_slot: bool = false ## Whether or not this crafting slot is an output slot.


func _set_item(new_item: InvItemResource) -> void:
	super._set_item(new_item)

	if is_output_slot:
		output_changed.emit(new_item != null)
		backing_texture_rect.visible = new_item == null

## Determines if the slot we are hovering over during a drag can accept drag data on mouse release.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data.item == null or not synced_inv or data.index == index or is_output_slot:
		return false
	if data is ModSlot:
		if item != null and not (item.stats.is_same_as(data.item.stats) and item.quantity < item.stats.stack_size):
			return false
	return true

func _get_drag_data(at_position: Vector2) -> Variant:
	if is_output_slot:
		return

	return super._get_drag_data(at_position)

func _gui_input(event: InputEvent) -> void:
	if is_output_slot:
		return

	super._gui_input(event)
