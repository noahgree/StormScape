@icon("res://Utilities/Debug/EditorIcons/inventory_ui.svg")
extends Control
class_name InventoryUI
## The base class for all inventory UIs. Handles drag and dropping into margin space for dropping onto the ground.

static var slot_scene: PackedScene = preload("res://UI/Inventory/InventoryCore/Slot/SlotCore/Slot.tscn") ## The slot scene to use to load slots according to the slot count of the synced inv.

@export var synced_inv_source_node: Node2D ## The node holding the inventory to connect to and reflect.
@export var main_slot_grid: GridContainer ## The main container for all normal inventory slots.

var slots: Array[Slot] = [] ## The array of slots that this populator fills.
var core_index_counter: int = 0 ## A separate counter to track the core slots (main grid, hotbar, trash slot).
var index_counter: int = 0 ## Counts up everytime a slot is assigned an index.


func _ready() -> void:
	visible = false
	link_new_inventory_source_node(synced_inv_source_node)

## Links a new source node and its inventory to this inventory UI.
func link_new_inventory_source_node(new_source_node: Node2D) -> void:
	if synced_inv_source_node != null and is_instance_valid(synced_inv_source_node):
		if synced_inv_source_node.inv.inv_data_updated.is_connected(_on_inv_data_updated):
			synced_inv_source_node.inv.inv_data_updated.disconnect(_on_inv_data_updated)

	_clear_old_slots()
	index_counter = 0
	core_index_counter = 0
	synced_inv_source_node = new_source_node

	if synced_inv_source_node:
		synced_inv_source_node.inv.inv_data_updated.connect(_on_inv_data_updated)
		_setup_main_slot_grid()
		call_deferred("_fill_slots_with_items")

## Returns the current index counter and then increments it to prepare for the next slot.
func assign_next_slot_index(core_slots: bool = false) -> int:
	if index_counter == 0: # Let core slots have those first indices
		index_counter = synced_inv_source_node.inv.main_inv_size + synced_inv_source_node.inv.hotbar_size + (1 if synced_inv_source_node is Player else 0) # +1 for trash slot

	var index: int = index_counter if not core_slots else core_index_counter
	core_index_counter += 1 if core_slots else 0
	index_counter += 1
	return index

## Clears out all the children slots.
func _clear_old_slots() -> void:
	slots.clear()
	for slot: Slot in main_slot_grid.get_children():
		slot.queue_free()

## Sets up the main slots of this inventory.
func _setup_main_slot_grid() -> void:
	for i: int in range(synced_inv_source_node.inv.main_inv_size):
		var slot: Slot = slot_scene.instantiate()
		slot.name = "Slot_" + str(index_counter)
		slot.index = assign_next_slot_index(true)
		slot.synced_inv = synced_inv_source_node.inv
		slots.append(slot)
		main_slot_grid.add_child(slot)

## Fills the inventory slots with whatever the inventory has at the start.
func _fill_slots_with_items() -> void:
	var i: int = 0
	for slot: Slot in slots:
		slot.set_item(synced_inv_source_node.inv.inv[i])
		i += 1

## When an index gets updated in the inventory, this is received via signal in order to update a slot here.
func _on_inv_data_updated(index: int, item: InvItemResource) -> void:
	slots[index].set_item(item)

#region Debug
## Custom printing method to show the items inside the slots populated by this node.
func print_slots(include_null_spots: bool = false) -> void:
	var to_print: String = "[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]\n"
	for i: int in range(slots.size()):
		if slots[i].item == null and not include_null_spots:
			continue
		to_print = to_print + str(slots[i])
		if (i + 1) % 5 == 0 and i != slots.size() - 1: to_print += "\n"
		elif i != slots.size() - 1: to_print += "  |  "
	if to_print.ends_with("\n"): to_print = to_print.substr(0, to_print.length() - 1)
	elif to_print.ends_with("|  "): to_print = to_print.substr(0, to_print.length() - 3)
	print_rich(to_print + "\n[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]")
#endregion
