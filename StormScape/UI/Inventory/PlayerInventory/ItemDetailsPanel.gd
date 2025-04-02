extends VBoxContainer
class_name ItemDetailsPanel
## This is responsible for handling the item details inside the player's inventory.
##
## You can drag and drop an item into the main slot to edit its mods and view more information about it.
## Every item is viewable, but only weapons with moddability have mod spots displayed.

@export var ammo_viewer_margin: MarginContainer ## The slot that shows the ammo type of the main viewed item.
@export var stamina_ammo_icon: Texture2D ## The icon used for stamina when displaying ammo type of viewed weapon.

@onready var item_viewer_slot: Slot = %ItemViewerSlot ## The slot that holds the item under review.
@onready var mod_slots_container: GridContainer = %ModSlots ## The container whose children are mod slots.
@onready var mod_slots_margin: MarginContainer = %ModSlotsMargin ## The margin container for the mod slots.
@onready var item_name_label: RichTextLabel = %ItemNameLabel ## Displays the item's name.
@onready var info_margin: MarginContainer = %InfoMargin ## The margin container for the info label.
@onready var details_margin: MarginContainer = %DetailsMargin ## The margin container for the details VBox.
@onready var info_label: Label = %InfoLabel ## Displays the info blurb about the item.
@onready var details_label_margin: MarginContainer = %DetailsLabelMargin ## The margin container for the details.
@onready var details_label: RichTextLabel = %DetailsLabel ## The details rich text label.
@onready var item_rarity_margin: MarginContainer = %ItemRarityMargin ## The margin container for the rarity label.
@onready var item_rarity_label: RichTextLabel = %ItemRarityLabel ## Displays the item's rarity and type.

var mod_slots: Array[ModSlot] = [] ## The mod slots that display and modify the mods for the item under review.
var changing_item_viewer_slot: bool = false ## When true, the item under review is changing and we shouldn't respond to mod slot item changes.
var item_details_creator: ItemDetailsCreator = ItemDetailsCreator.new() ## The helper script that compiles an array of details about the item passed to it.
var item_hover_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.4, _on_hover_delay_ended) ## The delay timer for showing what is hovered over when something is not pinned.
var pinned: bool = false ## When true, an item is pinned in the view slot and the slot should not populate with the item underneath the mouse.
var is_updating_via_hover: bool = false ## Flagged to true when the hovered slots are dictating what populates the item viewer.


func _ready() -> void:
	call_deferred("_setup_slots")

	SignalBus.focused_ui_closed.connect(_on_focused_ui_closed)
	SignalBus.slot_hovered.connect(_on_slot_hovered)
	SignalBus.slot_not_hovered.connect(_on_slot_not_hovered)

	visible = false
	item_rarity_margin.visible = false
	info_margin.visible = false
	details_margin.visible = false
	changing_item_viewer_slot = false
	ammo_viewer_margin.visible = false

## Sets up the mod slots and the item viewer slot with their needed data.
func _setup_slots() -> void:
	var inv: Inventory = Globals.player_node.inv
	var i: int = 1 # 1 since we are using the actual index of the last crafting slot to start with
	for slot: ModSlot in mod_slots_container.get_children():
		slot.name = "Mods_Input_Slot_" + str(i - 1)
		slot.mod_slot_index = (i - 1)
		slot.item_viewer_slot = item_viewer_slot
		slot.synced_inv = inv
		slot.index = Globals.player_node.get_node("%CraftingManager").output_slot.index + i
		slot.item_changed.connect(_on_mod_slot_changed)
		mod_slots.append(slot)
		i += 1

	item_viewer_slot.name = "Item_Viewer_Slot"
	item_viewer_slot.synced_inv = inv
	item_viewer_slot.index = Globals.player_node.get_node("%CraftingManager").output_slot.index + i
	item_viewer_slot.item_changed.connect(_on_item_viewer_slot_changed)

	mod_slots_margin.visible = false

## Received when any drag ends to hide the panel if the viewer slot is now null.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and item_viewer_slot.item == null:
		visible = false
	if what == NOTIFICATION_DRAG_BEGIN and _is_dragging_slot():
		if not pinned:
			_show_and_update_item_title("Drop Here to Pin")

## When the slot is hovered over, potentially start a delay for showing stats of the underneath item.
## If something is instead pinned, return and do nothing.
func _on_slot_hovered(slot: Slot) -> void:
	if pinned:
		return
	elif not _is_dragging_slot():
		item_hover_delay_timer.set_meta("slot", slot)
		item_hover_delay_timer.start()

## When a slot is no longer hovered over, stop the hover delay timer and remove the viewer slot item unless
## something is currently pinned.
func _on_slot_not_hovered() -> void:
	item_hover_delay_timer.stop()
	if not pinned:
		is_updating_via_hover = true
		if item_viewer_slot.item != null: # Don't want to trigger a clearing of crafting previews otherwise
			item_viewer_slot.item = null
		is_updating_via_hover = false

## When the focused UI is closed, we should empty out the crafting input slots and drop them on the
## ground if the inventory is now full.
func _on_focused_ui_closed() -> void:
	if item_viewer_slot.item != null:
		Globals.player_node.inv.insert_from_inv_item(item_viewer_slot.item, false, true)
		item_viewer_slot.item = null
	item_hover_delay_timer.stop()

## When the item inside a mod slot changes and the item under review isn't actively changing, we should modify
## the item's mods in it's stats.
func _on_mod_slot_changed(slot: ModSlot, old_item: InvItemResource, new_item: InvItemResource) -> void:
	if changing_item_viewer_slot:
		return

	if item_viewer_slot.item.stats is WeaponResource:
		if old_item != null:
			WeaponModsManager.remove_weapon_mod(item_viewer_slot.item.stats, old_item.stats, slot.mod_slot_index, Globals.player_node)
			_assign_details(item_viewer_slot.item.stats)

		if new_item != null:
			await get_tree().process_frame # Let the drag and drop finish and the removal happen before re-adding
			WeaponModsManager.handle_weapon_mod(item_viewer_slot.item.stats, new_item.stats, slot.mod_slot_index, Globals.player_node)
			_assign_details(item_viewer_slot.item.stats)

## When the item under review changes, we need to conditionally enable the mod slots and update the stats view.
func _on_item_viewer_slot_changed(_slot: Slot, _old_item: InvItemResource, new_item: InvItemResource) -> void:
	changing_item_viewer_slot = true

	ammo_viewer_margin.visible = false

	if new_item == null:
		if not _is_dragging_slot():
			visible = false
		else:
			_show_and_update_item_title("Drop Here to Pin")
		_change_mod_slot_visibilities(false)
		item_rarity_margin.visible = false
		info_margin.visible = false
		details_margin.visible = false
		changing_item_viewer_slot = false
		pinned = false
		return
	else:
		_show_and_update_item_title(new_item.stats.name)
		item_rarity_label.text = Globals.invis_char + new_item.stats.get_item_type_string(true) + " (" + new_item.stats.get_rarity_string().capitalize() + ") " + "[color=#93665800][char=02D9][/color]"
		item_rarity_margin.visible = true
		info_label.text = new_item.stats.info
		info_margin.visible = true
		_assign_details(new_item.stats)
		if not is_updating_via_hover:
			pinned = true

	if (new_item.stats is WeaponResource) and (new_item.stats.max_mods_override != 0):
		_change_mod_slot_visibilities(true, new_item.stats)
		var i: int = 0
		for weapon_mod_entry: Dictionary in new_item.stats.current_mods:
			if weapon_mod_entry.values()[0] != null:
				mod_slots[i].item = InvItemResource.new(weapon_mod_entry.values()[0], 1)
			i += 1
	else:
		_change_mod_slot_visibilities(false)

	if new_item.stats is WeaponResource:
		_update_ammo_viewer_slot(new_item.stats)

	changing_item_viewer_slot = false

## Updates the ammo viewer slot with the appropriate ammo type for the currently selected weapon.
func _update_ammo_viewer_slot(new_item: ItemResource) -> void:
	ammo_viewer_margin.visible = false
	if new_item is ProjWeaponResource:
		if new_item.ammo_type not in [ProjWeaponResource.ProjAmmoType.NONE, ProjWeaponResource.ProjAmmoType.SELF, ProjWeaponResource.ProjAmmoType.CHARGES]:
			ammo_viewer_margin.visible = true
			if new_item.ammo_type == ProjWeaponResource.ProjAmmoType.STAMINA:
				ammo_viewer_margin.get_node("%AmmoIcon").texture = stamina_ammo_icon
			else:
				var ammo_item: ProjAmmoResource = CraftingManager.get_item_by_id(ProjWeaponResource.get_ammo_item_id_by_enum_value(new_item.ammo_type))
				ammo_viewer_margin.get_node("%AmmoIcon").texture = ammo_item.inv_icon
	else:
		ammo_viewer_margin.visible = true
		ammo_viewer_margin.get_node("%AmmoIcon").texture = stamina_ammo_icon

## Changes the visibility of the mod slots depending on whether we have a moddable weapon under review.
func _change_mod_slot_visibilities(shown: bool, stats: WeaponResource = null) -> void:
	for slot: ModSlot in mod_slots:
		slot.item = null
		slot.is_hidden = not shown
		mod_slots_margin.visible = shown

		if shown:
			if slot.mod_slot_index + 1 > WeaponModsManager.get_max_mod_slots(stats):
				slot.is_hidden = true

## Show and update the new title.
func _show_and_update_item_title(title: String) -> void:
	visible = true
	item_name_label.text = Globals.invis_char + title + Globals.invis_char

## Calls on a helper script to assign details to each of the available labels based on the type of item.
## Any labels with no text are hidden. If none of the labels have any text, the entire margin container is hidden.
func _assign_details(stats: ItemResource) -> void:
	var details: Array[String] = item_details_creator.parse_item(stats)
	var string: String = ""
	details_label.text = ""

	var i: int = 0
	for item: String in details:
		i += 1
		if i != details.size():
			string += item
			string += "\n"
		else:
			details_label.text = string
			var last_break_position: int = details_label.get_parsed_text().length()
			string += item
			details_label.text = string

			var final_detail_starting_line: int = details_label.get_character_line(last_break_position) + 1
			var final_detail_ending_line: int = details_label.get_line_count()
			var final_detail_line_count: int = final_detail_ending_line - final_detail_starting_line

			if final_detail_line_count == 0:
				final_detail_line_count = 1
			details_label_margin.add_theme_constant_override("margin_bottom", 3 - final_detail_line_count)

	details_margin.visible = details_label.text != ""

## Returns true or false based on whether a slot is being dragged at the moment.
func _is_dragging_slot() -> bool:
	var drag_data: Variant
	if get_viewport().gui_is_dragging():
		drag_data = get_viewport().gui_get_drag_data()

	if drag_data != null and drag_data is Slot:
		return true
	return false

## When the delay for showing the details when something is not pinned is up, show the viewer panel.
func _on_hover_delay_ended() -> void:
	var slot: Variant = item_hover_delay_timer.get_meta("slot")
	if is_instance_valid(slot) and slot.item != null:
		is_updating_via_hover = true
		var temp_item: InvItemResource = InvItemResource.new(slot.item.stats, 1)
		item_viewer_slot.item = temp_item
		is_updating_via_hover = false
