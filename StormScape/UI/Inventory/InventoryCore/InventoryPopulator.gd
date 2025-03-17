extends Control
class_name InventoryPopulator
## Responsible for populating and instantiating slots of children nodes for the connected inventory.
##
## Slot indices for an example inventory of size 37 (including hotbar, excluding trash slot) are structured like so:
## 0 -> (36 - hotbar size): Main Slots ||| (36 - hotbar size) -> 36: Hotbar Slots
## 37: Trash Slot ||| 38 -> (37 + crafting slot count): Crafting Slots

@export var slot_scene: PackedScene = preload("res://UI/Inventory/InventoryCore/Slot/Slot.tscn") ## The slot scene to be instantiated as children.
@export var item_details_label: Label ## The label in the inventory that displays the details of a hovered over item.
@export var main_slot_grid: GridContainer ## The main container for all normal inventory slots.
@export var hotbar_grid: HBoxContainer ## If player inv, this connects to the container that holds the hotbar slots.
@export var trash_slot: Slot ## If player inv, this connects to the trash slot.
@export var crafting_manager: CraftingManager ## If player inv, this connects to the crafting manager.

var synced_inv: Inventory ## The synced inventory that this populator populates based on.
var slots: Array[Slot] = [] ## The array of slots that this populator fills.
const DEFAULT_SLOT_COUNT: int = 32 ## The default amount of slots an inventory should have.


## Clears all children slots and sets up trash slot if needed. Changes slot count to default amount.
func _ready() -> void:
	for child: Slot in main_slot_grid.get_children():
		child.queue_free()
	if hotbar_grid:
		for child: Slot in hotbar_grid.get_children():
			child.queue_free()
	if trash_slot != null:
		trash_slot.is_trash_slot = true
		trash_slot.name = "Trash_Slot"
		trash_slot.is_hovered_over.connect(_on_slot_hovered)
		trash_slot.is_not_hovered_over.connect(_on_slot_not_hovered)

	_change_slot_count_for_new_inv()

## Recreates the slot children and updates the slots array based on a passed in inventory.
## Sets needed slot variables.
func _change_slot_count_for_new_inv(inv: Inventory = null) -> void:
	for slot: Slot in slots:
		slot.queue_free()
	slots = []

	var main_count: int = DEFAULT_SLOT_COUNT
	var hotbar_count: int = 0

	if inv and inv.is_player_inv:
		main_count = inv.inv_size - inv.hotbar_size
		hotbar_count = inv.hotbar_size
		trash_slot.index = inv.inv_size
		trash_slot.synced_inv = inv

	for i: int in range(main_count):
		var slot: Slot = slot_scene.instantiate()
		main_slot_grid.add_child(slot)
		slot.name = "Slot_" + str(i)
		slot.is_hovered_over.connect(_on_slot_hovered)
		slot.is_not_hovered_over.connect(_on_slot_not_hovered)
		slot.index = i
		if inv: slot.synced_inv = inv
		slots.append(slot)

	for i: int in range(hotbar_count):
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

		if crafting_manager != null:
			if not crafting_manager.is_node_ready():
				await crafting_manager.ready

			var i: int = 0
			for input_slot: CraftingSlot in crafting_manager.get_node("%InputSlots").get_children():
				input_slot.name = "Input_Slot_" + str(i)
				input_slot.synced_inv = inv
				input_slot.index = inv.inv_size + 1 + i # The 1 is for the trash slot
				input_slot.item_changed.connect(crafting_manager.update_crafting_result)
				crafting_manager.input_slots.append(input_slot)
				i += 1
			crafting_manager.output_slot.name = "Output_Slot"
			crafting_manager.output_slot.synced_inv = inv
			crafting_manager.output_slot.index = inv.inv_size + 1 + i

## Called externally to connect this populator to its synced inventory.
func connect_inventory(inv: Inventory) -> void:
	if synced_inv:
		synced_inv.slot_updated.disconnect(_on_slot_updated)

	synced_inv = inv
	synced_inv.slot_updated.connect(_on_slot_updated)
	call_deferred("_set_synced_ui")

## Calls the slot count changing method when a new inventory gets connected. Fills items from new inv into slots.
func _set_synced_ui() -> void:
	_change_slot_count_for_new_inv(synced_inv)

	for i: int in range(slots.size()):
		slots[i].item = synced_inv.inv[i]

## When a slot gets updated in the inventory, this is received via signal in order to update a slot visual here.
func _on_slot_updated(index: int, item: InvItemResource) -> void:
	slots[index].item = item

## When a slot is hovered, update the item details label if that slot's item is not null.
func _on_slot_hovered(index: int) -> void:
	if item_details_label and slots[index].item != null:
		item_details_label.text = slots[index].item.stats.info

## When the mouse stops hovering over an item, clear the details label.
func _on_slot_not_hovered() -> void:
	if item_details_label: item_details_label.text = ""

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
