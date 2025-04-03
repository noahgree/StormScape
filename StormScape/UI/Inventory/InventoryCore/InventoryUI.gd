@icon("res://Utilities/Debug/EditorIcons/inventory_ui.svg")
extends ColorRect
class_name InventoryUI
## The base class for all inventory UIs. Handles drag and dropping into margin space for dropping onto the ground.

@export var synced_inv: Inventory ## The inventory to connect to and reflect.
@export var main_slot_grid: GridContainer ## The main container for all normal inventory slots.

var slots: Array[Slot] = [] ## The array of slots that this populator fills.
var core_index_counter: int = 0 ## A separate counter to track the core slots (main grid, hotbar, trash slot).
var index_counter: int = 0 ## Counts up everytime a slot is assigned an index.


func _ready() -> void:
	visible = false
	gui_input.connect(_on_blank_space_input_event)
	synced_inv.inv_data_updated.connect(_on_inv_data_updated)

	_setup_main_slot_grid()

	call_deferred("_fill_slots_with_initial_items") # Wait for synced inv to load

## Returns the current index counter and then increments it to prepare for the next slot.
func assign_next_slot_index(core_slots: bool = false) -> int:
	if index_counter == 0: # Let core slots have those first indices
		index_counter = synced_inv.main_inv_size + synced_inv.hotbar_size + (1 if synced_inv.is_player_inv else 0)

	var index: int = index_counter if not core_slots else core_index_counter
	core_index_counter += 1 if core_slots else 0
	index_counter += 1
	return index

## Sets up the main slots of this inventory.
func _setup_main_slot_grid() -> void:
	for slot: Slot in main_slot_grid.get_children():
		slot.name = "Slot_" + str(index_counter)
		slot.index = assign_next_slot_index(true)
		slot.synced_inv = synced_inv
		slots.append(slot)

## Fills the inventory slots with whatever the inventory has at the start.
func _fill_slots_with_initial_items() -> void:
	var i: int = 0
	for slot: Slot in slots:
		slot.set_item(synced_inv.inv[i])
		i += 1

## When an index gets updated in the inventory, this is received via signal in order to update a slot here.
func _on_inv_data_updated(index: int, item: InvItemResource) -> void:
	slots[index].set_item(item)

## Determines if this control node can have item slot data dropped into it.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if (data != null) and ("item" in data) and (data.item != null):
		return true
	else:
		return false

## Runs the logic for what to do when we can drop an item slot's data at the current moment.
## Creates physical items on the ground.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var ground_item_res: ItemResource = data.item.stats
	var ground_item_quantity: int = 1
	if ground_item_res and data:
		if data.dragging_only_one:
			ground_item_quantity = 1
			if data.item.quantity < 2:
				data.set_item(null)
			else:
				data.item.quantity -= 1
				data.set_item(data.item)
		elif data.dragging_half_stack:
			var half_quantity: int = int(floor(data.item.quantity / 2.0))
			var remainder: int = data.item.quantity - half_quantity
			ground_item_quantity = half_quantity

			data.item.quantity = remainder
			data.set_item(data.item)
		else:
			ground_item_quantity = data.item.quantity
			data.set_item(null)

		Item.spawn_on_ground(ground_item_res, ground_item_quantity, Globals.player_node.global_position, 15, true, false, true)

	data._on_mouse_exited()

## When the empty space of the inventory screen is clicked, we close the inventory altogether.
func _on_blank_space_input_event(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("primary"):
		visible = false
		get_tree().paused = false

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
