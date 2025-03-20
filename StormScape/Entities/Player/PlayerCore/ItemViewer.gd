extends VBoxContainer
class_name ItemViewer
## This is responsible for handling the item details inside the player's inventory.
##
## You can drag and drop an item into the main slot to edit its mods and view more information about it.
## Every item is viewable, but only weapons with moddability have mod spots displayed.

@onready var item_viewer_slot: Slot = %ItemViewerSlot ## The slot that holds the item under review.
@onready var mod_slots_container: GridContainer = %ModSlots ## The container whose children are mod slots.
@onready var item_name_label: Label = %ItemNameLabel ## Displays the item's name.
@onready var mod_slots_margin: MarginContainer = %ModSlotsMargin
@onready var item_name_margin: MarginContainer = %ItemNameMargin
@onready var info_margin: MarginContainer = %InfoMargin
@onready var details_margin: MarginContainer = %DetailsMargin

var mod_slots: Array[ModSlot] = [] ## The mod slots that display and modify the mods for the item under review.
var changing_item_viewer_slot: bool = false ## When true, the item under review is changing and we shouldn't respond to mod slot item changes.


func _ready() -> void:
	call_deferred("_setup_slots")
	SignalBus.focused_ui_closed.connect(_on_focused_ui_closed)
	item_name_label.text = "No Item Selected"
	info_margin.visible = false
	details_margin.visible = false
	changing_item_viewer_slot = false

## Sets up the mod slots and the item viewer slot with their needed data.
func _setup_slots() -> void:
	var inv: Inventory = GlobalData.player_node.inv
	var i: int = 1 # 1 since we are using the actual index of the last crafting slot to start with
	for slot: ModSlot in mod_slots_container.get_children():
		slot.name = "Mods_Input_Slot_" + str(i - 1)
		slot.mod_slot_index = (i - 1)
		slot.item_viewer_slot = item_viewer_slot
		slot.synced_inv = inv
		slot.index = GlobalData.player_node.get_node("%CraftingManager").output_slot.index + i
		slot.item_changed.connect(_on_mod_slot_changed)
		mod_slots.append(slot)
		i += 1

	item_viewer_slot.name = "Item_Viewer_Slot"
	item_viewer_slot.synced_inv = inv
	item_viewer_slot.index = GlobalData.player_node.get_node("%CraftingManager").output_slot.index + i
	item_viewer_slot.item_changed.connect(_on_item_viewer_slot_changed)

	mod_slots_margin.visible = false

## When the focused UI is closed, we should empty out the crafting input slots and drop them on the
## ground if the inventory is now full.
func _on_focused_ui_closed() -> void:
	if item_viewer_slot.item != null:
		GlobalData.player_node.inv.add_item_from_inv_item_resource(item_viewer_slot.item, false)
		item_viewer_slot.item = null

## When the item inside a mod slot changes and the item under review isn't actively changing, we should modify
## the item's mods in it's stats.
func _on_mod_slot_changed(slot: ModSlot, old_item: InvItemResource, new_item: InvItemResource) -> void:
	if changing_item_viewer_slot:
		return

	if item_viewer_slot.item.stats is WeaponResource:
		if old_item != null:
			GlobalData.player_node.hands.weapon_mod_manager.remove_weapon_mod(item_viewer_slot.item.stats, old_item.stats, slot.mod_slot_index)

		if new_item != null:
			await get_tree().process_frame # Let the drag and drop finish and the removal happen before re-adding
			GlobalData.player_node.hands.weapon_mod_manager.handle_weapon_mod(item_viewer_slot.item.stats, new_item.stats, slot.mod_slot_index)

## When the item under review changes, we need to conditionally enable the mod slots and update the stats view.
func _on_item_viewer_slot_changed(_slot: Slot, _old_item: InvItemResource, new_item: InvItemResource) -> void:
	changing_item_viewer_slot = true

	if new_item == null:
		_change_mod_slot_visibilities(false)
		item_name_label.text = "No Item Selected"
		info_margin.visible = false
		details_margin.visible = false
		changing_item_viewer_slot = false
		return
	else:
		item_name_label.text = new_item.stats.name
		info_margin.visible = true
		details_margin.visible = true

	if (new_item.stats is WeaponResource) and (not new_item.stats.block_all_mods):
		_change_mod_slot_visibilities(true)

		var i: int = 0
		for weapon_mod_entry: Dictionary in new_item.stats.current_mods:
			if weapon_mod_entry.values()[0] != null:
				mod_slots[i].item = InvItemResource.new(weapon_mod_entry.values()[0], 1)
			i += 1
	else:
		_change_mod_slot_visibilities(false)

	changing_item_viewer_slot = false

## Changes the visibility of the mod slots depending on whether we have a moddable weapon under review.
func _change_mod_slot_visibilities(shown: bool) -> void:
	for slot: ModSlot in mod_slots:
		slot.item = null
		slot.is_hidden = not shown
		mod_slots_margin.visible = shown
