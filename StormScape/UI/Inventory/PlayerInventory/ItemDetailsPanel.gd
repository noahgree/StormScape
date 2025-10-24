extends CenterContainer
class_name ItemDetailsPanel
## This is responsible for handling the item details inside the player's inventory.
##
## You can drag and drop an item into the main slot to edit its mods and view more information about it.
## Every item is viewable, but only weapons with moddability have mod spots displayed.

@export_group("Connections")
@export var inventory_ui: PlayerInvUI ## The main controller for all inventory sub-UIs.
@export_group("Textures")
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
@onready var player_icon_margin: MarginContainer = %PlayerIconMargin
@onready var main_item_viewer_margin: MarginContainer = %ItemViewerBkgrdMargin

var mod_slots: Array[ModSlot] = [] ## The mod slots that display and modify the mods for the item under review.
var changing_item_viewer_slot: bool = false ## When true, the item under review is changing and we shouldn't respond to mod slot item changes.
var item_details_creator: ItemDetailsCreator = ItemDetailsCreator.new() ## The helper script that compiles an array of details about the item passed to it.
var item_hover_delay_timer: Timer = TimerHelpers.create_one_shot_timer(self, 0.38, _on_hover_delay_ended) ## The delay timer for showing what is hovered over when something is not pinned.
var pinned: bool = false ## When true, an item is pinned in the view slot and the slot should not populate with the item underneath the mouse.
var is_updating_via_hover: bool = false ## Flagged to true when the hovered slots are dictating what populates the item viewer.
var is_still_setting_up: bool = true ## When true, don't try and populate the stats panel, as we are waiting for nodes to finish setting up.


func _ready() -> void:
	SignalBus.focused_ui_closed.connect(_on_focused_ui_closed)
	SignalBus.slot_hovered.connect(_on_slot_hovered)
	SignalBus.slot_not_hovered.connect(_on_slot_not_hovered)

	visible = false
	item_rarity_margin.visible = false
	info_margin.visible = false
	details_margin.visible = false
	changing_item_viewer_slot = false

	if Globals.player_node == null:
		await SignalBus.player_ready
	is_still_setting_up = false

	_setup_slots()

## Sets up the mod slots and the item viewer slot with their needed data.
func _setup_slots() -> void:
	var i: int = 0
	for slot: ModSlot in mod_slots_container.get_children():
		slot.name = "Mods_Input_Slot_" + str(i)
		slot.mod_slot_index = i
		slot.item_viewer_slot = item_viewer_slot
		slot.synced_inv = inventory_ui.synced_inv_source_node.inv
		slot.index = inventory_ui.assign_next_slot_index()
		slot.item_changed.connect(_on_mod_slot_changed)
		mod_slots.append(slot)
		i += 1

	item_viewer_slot.synced_inv = inventory_ui.synced_inv_source_node.inv
	item_viewer_slot.index = inventory_ui.assign_next_slot_index()
	item_viewer_slot.item_changed.connect(_on_item_viewer_slot_changed)

	mod_slots_margin.visible = false

## If the panel is not already visible and showing something like an item or a drop prompt, show the player stats.
func show_player_stats() -> void:
	if not visible:
		_show_and_update_item_title("My Stats")
		item_rarity_margin.visible = false
		info_margin.visible = false
		details_margin.visible = true
		main_item_viewer_margin.visible = false
		player_icon_margin.visible = true
		_assign_player_details()

## Hides the player stats if it is the only thing showing.
func hide_player_stats() -> void:
	if not main_item_viewer_margin.visible:
		visible = false

## Received when any drag ends to hide the panel if the viewer slot is now null.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and item_viewer_slot.item == null:
		visible = false
	if what == NOTIFICATION_DRAG_BEGIN and _is_dragging_slot():
		if not pinned:
			_show_and_update_item_title("Drop Above to Pin")
			player_icon_margin.visible = false
			details_margin.visible = false
			main_item_viewer_margin.visible = true

## When the slot is hovered over, potentially start a delay for showing stats of the underneath item.
## If something is instead pinned, return and do nothing.
func _on_slot_hovered(slot: Slot) -> void:
	if not _is_dragging_slot():
		item_hover_delay_timer.set_meta("slot", slot)
		item_hover_delay_timer.start()

## When a slot is no longer hovered over, stop the hover delay timer and remove the viewer slot item unless
## something is currently pinned.
func _on_slot_not_hovered() -> void:
	CursorManager.hide_tooltip()
	item_hover_delay_timer.stop()
	if not pinned:
		is_updating_via_hover = true
		if item_viewer_slot.item != null: # Don't want to trigger a clearing of crafting previews otherwise
			item_viewer_slot.set_item(null)
		is_updating_via_hover = false

## When the focused UI is closed, we should empty out the crafting input slots and drop them on the
## ground if the inventory is now full.
func _on_focused_ui_closed() -> void:
	if item_viewer_slot.item != null:
		Globals.player_node.inv.insert_from_inv_item(item_viewer_slot.item, false, true)
		item_viewer_slot.set_item(null)
	item_hover_delay_timer.stop()

## When the item inside a mod slot changes and the item under review isn't actively changing, we should modify
## the item's mods in it's stats.
func _on_mod_slot_changed(slot: ModSlot, old_item: InvItemResource, new_item: InvItemResource) -> void:
	if changing_item_viewer_slot:
		return

	if item_viewer_slot.item.stats is WeaponResource:
		if old_item != null:
			WeaponModsManager.remove_weapon_mod(item_viewer_slot.item.stats, old_item.stats, slot.mod_slot_index, Globals.player_node)
			_assign_item_details(item_viewer_slot.item.stats)

		if new_item != null:
			await get_tree().process_frame # Let the drag and drop finish and the removal happen before re-adding
			WeaponModsManager.handle_weapon_mod(item_viewer_slot.item.stats, new_item.stats, slot.mod_slot_index, Globals.player_node)
			_assign_item_details(item_viewer_slot.item.stats)

		item_viewer_slot.update_corner_icons(item_viewer_slot.item)

## When the item under review changes, we need to conditionally enable the mod slots and update the stats view.
func _on_item_viewer_slot_changed(_slot: Slot, _old_item: InvItemResource, new_item: InvItemResource) -> void:
	changing_item_viewer_slot = true

	player_icon_margin.visible = false

	if new_item == null:
		_change_mod_slot_visibilities(false)
		item_rarity_margin.visible = false
		info_margin.visible = false
		details_margin.visible = false
		pinned = false

		if not _is_dragging_slot():
			visible = false
		else:
			main_item_viewer_margin.visible = true
			_show_and_update_item_title("Drop Above to Pin")

		changing_item_viewer_slot = false
		return
	else:
		_show_and_update_item_title(new_item.stats.name)
		main_item_viewer_margin.visible = true
		var item_type_string: String = new_item.stats.get_rarity_string().to_upper() + " " + new_item.stats.get_item_type_string(true) + "  "
		var type_color_hex: String = Globals.rarity_colors.ui_text.get(new_item.stats.rarity).to_html(false)
		item_rarity_label.text = Globals.invis_char + "[color=" + type_color_hex + "]" + item_type_string + "[/color]"
		item_rarity_margin.visible = true
		info_label.text = new_item.stats.info
		info_margin.visible = true
		_assign_item_details(new_item.stats)
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
		if not new_item.stats.no_levels:
			var level_string: String = "• [color=Cyan] LVL " + str(new_item.stats.level) + "[/color][color=AAAAAA00][char=02D9][/color]" + "[color=AAAAAA00][char=02D9][/color]"
			item_rarity_label.text += level_string

	changing_item_viewer_slot = false

## Changes the visibility of the mod slots depending on whether we have a moddable weapon under review.
func _change_mod_slot_visibilities(shown: bool, stats: WeaponResource = null) -> void:
	for slot: ModSlot in mod_slots:
		slot.set_item(null)
		slot.is_hidden = not shown
		mod_slots_margin.visible = shown

		if shown:
			if slot.mod_slot_index + 1 > WeaponModsManager.get_max_mod_slots(stats):
				slot.is_hidden = true

## Show the panel and update the new title.
func _show_and_update_item_title(title: String) -> void:
	visible = true
	item_name_label.text = Globals.invis_char + title + Globals.invis_char

## Gets the details for the currently viewed item stats.
func _assign_item_details(stats: ItemResource) -> void:
	if is_still_setting_up:
		return
	var details: Array[String] = item_details_creator.parse_item(stats)
	_format_and_update_details(details)

## Gets the details for the player.
func _assign_player_details() -> void:
	if is_still_setting_up:
		return
	var details: Array[String] = item_details_creator.parse_player()
	_format_and_update_details(details)

## Formats the item details label depending on the contents.
func _format_and_update_details(details: Array[String]) -> void:
	details_label.text = ""
	var string: String = ""
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
	if not is_instance_valid(slot):
		return
	if pinned:
		if slot.hide_hover_tooltip:
			return
		if slot.item != null:
			var info: String = slot.item.stats.get_item_type_string(true)
			if slot.item.stats is WeaponResource and not slot.item.stats.no_levels:
				info += " (LVL " + str(slot.item.stats.level) + ")"
			CursorManager.update_tooltip(slot.item.stats.name, info, Globals.rarity_colors.ui_text.get(slot.item.stats.rarity))
	elif slot.item != null:
		is_updating_via_hover = true
		var temp_item: InvItemResource = InvItemResource.new(slot.item.stats, 1)
		item_viewer_slot.set_item(temp_item)
		is_updating_via_hover = false
