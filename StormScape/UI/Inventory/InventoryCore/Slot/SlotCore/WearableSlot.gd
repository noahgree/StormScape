@icon("res://Utilities/Debug/EditorIcons/slot.svg")
extends Slot
class_name WearableSlot
## A child class of Slot that changes the conditions for which data can be dropped.

var wearable_slot_index: int ## The index within the grid of wearable slots.


## Determines if the slot we are hovering over during a drag can accept drag data on mouse release.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data.item == null or not synced_inv or data.index == index or not data.item.stats is Wearable:
		return false
	if not WearablesManager.check_wearable_compatibility(Globals.player_node, data.item.stats):
		return false
	if WearablesManager.has_wearable(Globals.player_node, data.item.stats.id):
		if data is not WearableSlot:
			return false

	return true

## An override for _drop_data that limits dropping a max quantity of 1.
func _drop_data(at_position: Vector2, data: Variant) -> void:
	super._drop_data(at_position, data)

	if item != null:
		if item.quantity > 1:
			var extra_items: InvItemResource = InvItemResource.new(item.stats, item.quantity - 1)
			synced_inv.insert_from_inv_item(extra_items, false, false)
			item.quantity = 1
			pause_changed_signals = true
			set_item(item)
			pause_changed_signals = false
