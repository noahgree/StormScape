extends Control
class_name InventoryPopulator

@export var slot_scene: PackedScene = load("res://UI/Inventory/Slot/Slot.tscn")
@export var item_details_label: Label
@export var main_slot_grid: GridContainer
@export var hotbar_grid: HBoxContainer
@export var trash_slot: Slot

var synced_inv: Inventory
var slots: Array[Slot] = []
const DEFAULT_SLOT_COUNT: int = 32


func _ready() -> void:
	for child in main_slot_grid.get_children():
		child.queue_free()
	if hotbar_grid:
		for child in hotbar_grid.get_children():
			child.queue_free()
	if trash_slot:
		trash_slot.is_trash_slot = true
		trash_slot.name = "Trash_Slot"
		trash_slot.is_hovered_over.connect(_on_slot_hovered)
		trash_slot.is_not_hovered_over.connect(_on_slot_not_hovered)
	_change_slot_count_for_new_inv()

func _change_slot_count_for_new_inv(inv: Inventory = null) -> void:
	for slot in slots:
		slot.queue_free()
	slots = []

	var main_count: int = DEFAULT_SLOT_COUNT
	var hotbar_count: int = 0
	if inv and inv.is_player_inv:
		main_count = inv.inv_size - inv.hotbar_size
		hotbar_count = inv.hotbar_size
		trash_slot.index = inv.inv_size
		trash_slot.synced_inv = inv
	for i in range(main_count):
		var slot: Slot = slot_scene.instantiate()
		main_slot_grid.add_child(slot)
		slot.name = "Slot_" + str(i)
		slot.is_hovered_over.connect(_on_slot_hovered)
		slot.is_not_hovered_over.connect(_on_slot_not_hovered)
		slot.index = i
		if inv: slot.synced_inv = inv
		slots.append(slot)
	for i in range(hotbar_count):
		var slot: Slot = slot_scene.instantiate()
		hotbar_grid.add_child(slot)
		slot.name = "HotSlot_" + str(i)
		slot.is_hovered_over.connect(_on_slot_hovered)
		slot.is_not_hovered_over.connect(_on_slot_not_hovered)
		slot.index = main_count + i
		if inv: slot.synced_inv = inv
		slots.append(slot)
	if inv and inv.is_player_inv:
		slots.append(trash_slot)

func connect_inventory(inv: Inventory) -> void:
	if synced_inv:
		synced_inv.slot_updated.disconnect(_on_slot_updated)

	synced_inv = inv
	synced_inv.slot_updated.connect(_on_slot_updated)
	call_deferred("_set_synced_ui")

func _set_synced_ui() -> void:
	_change_slot_count_for_new_inv(synced_inv)

	for i in range(slots.size()):
		slots[i].item = synced_inv.inv[i]

func _on_slot_updated(index: int, item: InventoryItem) -> void:
	slots[index].item = item

func _on_slot_hovered(index) -> void:
	if item_details_label and slots[index].item != null:
		item_details_label.text = slots[index].item.stats.info

func _on_slot_not_hovered() -> void:
	if item_details_label: item_details_label.text = ""

func print_slots(include_null_spots: bool = false) -> void:
	var to_print: String = "[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]\n"
	for i in range(slots.size()):
		if slots[i].item == null and not include_null_spots:
			continue
		to_print = to_print + str(slots[i])
		if (i + 1) % 5 == 0 and i != slots.size() - 1: to_print += "\n"
		elif i != slots.size() - 1: to_print += "  |  "
	if to_print.ends_with("\n"): to_print = to_print.substr(0, to_print.length() - 1)
	elif to_print.ends_with("|  "): to_print = to_print.substr(0, to_print.length() - 3)
	print_rich(to_print + "\n[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]")
