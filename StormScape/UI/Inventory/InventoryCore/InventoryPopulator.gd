extends NinePatchRect
class_name InventoryPopulator
## Responsible for populating and instantiating slots of children nodes for the connected inventory.
##
## Slot indices for an example inventory of size 37 (including hotbar, excluding trash slot) are structured like so:
## 0 -> (36 - hotbar size): Main Slots
## (36 - hotbar size) -> 36: Hotbar Slots
## 37: Trash Slot
## 38 -> 41: Crafting Slots
## 42 -> 47: Mod Slots
## 48: Item Viewer Slot
## 49 -> 52: Wearables Slots

@export var slot_scene: PackedScene = preload("res://UI/Inventory/InventoryCore/Slot/SlotCore/Slot.tscn") ## The slot scene to be instantiated as children.
@export var main_slot_grid: GridContainer ## The main container for all normal inventory slots.
@export var hotbar_grid: HBoxContainer ## If player inv, this connects to the container that holds the hotbar slots.
@export var trash_slot: Slot ## If player inv, this connects to the trash slot.
@export var crafting_manager: CraftingManager ## If player inv, this connects to the crafting manager.
@export var item_viewer: ItemDetailsPanel ## If player inv, this connects to the item viewer in the inventory.

var synced_inv: Inventory ## The synced inventory that this populator populates based on.
var slots: Array[Slot] = [] ## The array of slots that this populator fills.
var hotbar_backing_texture: Texture2D ## Saves a copy of the backing texture for the hotbar slots before deleting and readding them.
const DEFAULT_SLOT_COUNT: int = 32 ## The default amount of slots an inventory should have.
const WEARABLES_SLOTS: int = 5 ## Manually set based on how many of those slots exist in the player inv.


## Clears all children slots and sets up trash slot if needed. Changes slot count to default amount.
func _ready() -> void:
	for slot: Slot in main_slot_grid.get_children():
		slot.queue_free()
	if hotbar_grid:
		for slot: Slot in hotbar_grid.get_children():
			hotbar_backing_texture = slot.backing_texture
			slot.queue_free()
	if trash_slot != null:
		trash_slot.is_trash_slot = true
		trash_slot.name = "Trash_Slot"

	_change_slot_count_for_new_inv()

## Recreates the slot children and updates the slots array based on a passed in inventory.
## Sets needed slot variables.
func _change_slot_count_for_new_inv(inv: Inventory = null) -> void:
	for slot: Slot in slots:
		slot.queue_free()
	slots.clear()

	var main_count: int = DEFAULT_SLOT_COUNT
	var hotbar_count: int = 0

	if inv and inv.is_player_inv:
		main_count = inv.inv_size - inv.hotbar_size
		hotbar_count = inv.hotbar_size
		trash_slot.index = inv.inv_size
		trash_slot.synced_inv = inv

	# Main Inventory Slots
	for i: int in range(main_count):
		var slot: Slot = slot_scene.instantiate()
		main_slot_grid.add_child(slot)
		slot.name = "Slot_" + str(i)
		slot.index = i
		if inv: slot.synced_inv = inv
		slots.append(slot)

	# Hotbar Slots
	for i: int in range(hotbar_count):
		var slot: Slot = slot_scene.instantiate()
		hotbar_grid.add_child(slot)
		slot.name = "HotSlot_" + str(i)
		slot.index = main_count + i
		if inv: slot.synced_inv = inv
		slots.append(slot)
		if hotbar_backing_texture != null:
			slot.backing_texture_rect.texture = hotbar_backing_texture

	# Trash Slot
	if inv and inv.is_player_inv:
		slots.append(trash_slot)

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
