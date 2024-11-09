extends NinePatchRect
class_name HotbarUI
## The player's hotbar UI controller. Handles logic for the hotbar shown when the inventory is not open.

@export var player_inv: Inventory ## The connected player inventory to reflect as a UI.

@onready var hotbar: HBoxContainer = %HotbarUISlotGrid ## The container that holds the hotbar slots.

var hotbar_slots: Array[Slot] = [] ## Local representation of the hoytbar slots, updated when changed externally.


## Connects the hotbar slots to the signal needed to keep them up to date.
func _ready() -> void:
	player_inv.slot_updated.connect(_on_slot_updated)
	for i in range(hotbar.get_child_count()):
		hotbar.get_child(i).is_hotbar_ui_preview_slot = true
		hotbar.get_child(i).synced_inv = player_inv
		hotbar.get_child(i).index = player_inv.inv_size - player_inv.hotbar_size + i
		hotbar_slots.append(hotbar.get_child(i))

## When receiving the signal that a slot has changed, update the visuals.
func _on_slot_updated(index: int, item: InventoryItem) -> void:
	var hotbar_slot_count: int = player_inv.inv_size - player_inv.hotbar_size
	if index >= hotbar_slot_count:
		if index < player_inv.inv_size:
			hotbar_slots[index - hotbar_slot_count].item = item
