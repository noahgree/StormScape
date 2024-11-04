extends GridContainer
class_name InventoryPopulator

@export var slot_scene: PackedScene
@export var item_details_label: Label

var synced_inv: Inventory
var slots: Array[Slot] = []
const DEFAULT_SLOT_COUNT: int = 32


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_change_slot_count(DEFAULT_SLOT_COUNT)

func _change_slot_count(count: int) -> void:
	for slot in slots:
		slot.queue_free()
	slots = []
	for i in range(count):
		var slot: Slot = slot_scene.instantiate()
		add_child(slot)
		slot.name = "Slot_" + str(i)
		slot.is_hovered_over.connect(_on_slot_hovered)
		slot.is_not_hovered_over.connect(_on_slot_not_hovered)
		slots.append(slot)

func connect_inventory(inv: Inventory) -> void:
	if synced_inv:
		synced_inv.slot_updated.disconnect(_on_slot_updated)

	synced_inv = inv
	synced_inv.slot_updated.connect(_on_slot_updated)
	call_deferred("_set_synced_ui")

func _set_synced_ui() -> void:
	for i in range(slots.size()):
		slots[i].item = null
		slots[i].index = i
		slots[i].synced_inv = synced_inv
	if slots.size() != synced_inv.inv.size():
		_change_slot_count(synced_inv.inv.size())

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
