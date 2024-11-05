extends NinePatchRect
class_name HotbarUI

@export var player_inv: Inventory

@onready var hotbar: HBoxContainer = %HotbarUISlotGrid

var hotbar_slots: Array[Slot] = []


func _ready() -> void:
	player_inv.slot_updated.connect(_on_slot_updated)
	for i in range(hotbar.get_child_count()):
		hotbar.get_child(i).is_hotbar_ui_preview_slot = true
		hotbar.get_child(i).synced_inv = player_inv
		hotbar.get_child(i).index = player_inv.inv_size - player_inv.hotbar_size + i
		hotbar_slots.append(hotbar.get_child(i))

func _on_slot_updated(index: int, item: InventoryItem) -> void:
	var hotbar_slot_count: int = player_inv.inv_size - player_inv.hotbar_size
	if index >= hotbar_slot_count:
		hotbar_slots[index - hotbar_slot_count].item = item
