@icon("res://Utilities/Debug/EditorIcons/inventory_ui.svg")
extends InvSlotManager
class_name PlayerInvUI
## An child class of the inventory UI that adds functions specific to the player inventory.

@export_group("Textures")
@export var btn_up_texture: Texture2D ## The texture for buttons when not pressed.
@export var btn_down_texture: Texture2D ## The texture for buttons when pressed.

@onready var hotbar_grid: HBoxContainer = %HotbarGrid ## The container that holds the hotbar slots.
@onready var hotbar_hud_grid: HBoxContainer = %HotbarHUDGrid ## The container that holds the HUD-only hotbar slots.
@onready var trash_slot: Slot = %TrashSlot ## The trash slot.
@onready var item_details_panel: ItemDetailsPanel = %ItemDetailsPanel ## The item viewer in the inventory.
@onready var crafting_manager: CraftingManager = %CraftingManager ## The crafting manager panel.
@onready var wearables_panel: WearablesPanel = %WearablesPanel ## The wearables panel.
@onready var side_panel_mgr: SidePanelManager = %SidePanelManager ## The side panel that fills with alternate UIs like chests.

@onready var sort_by_name_btn: NinePatchRect = %SortByName ## The sort by name button.
@onready var sort_by_type_btn: NinePatchRect = %SortByType ## The sort by type button.
@onready var sort_by_rarity_btn: NinePatchRect = %SortByRarity ## The sort by rarity button.
@onready var auto_stack_btn: NinePatchRect = %AutoStack ## The autostacking button.
@onready var craft_btn: NinePatchRect = %CraftBackground ## The craft button.

var is_open: bool = false: set = _toggle_inventory_ui ## True when the inventory is open and showing.
var side_panel_active: bool = false: set = _toggle_side_panel ## When true, the alternate inv is open and the wearable & crafting panels should be hidden.


func _ready() -> void:
	if not Globals.player_node:
		await SignalBus.player_ready

	super()

	gui_input.connect(_on_blank_space_input_event)

	_setup_hotbar_slots()
	_setup_trash_slot()

## Sets up the in-inventory hotbar slots with their needed data. They are considered core slots
## and tracked by the inventory resource.
func _setup_hotbar_slots() -> void:
	var i: int = 0
	for slot: Slot in hotbar_grid.get_children():
		slot.name = "HotSlot_" + str(index_counter)
		slot.index = assign_next_slot_index(true)
		slot.synced_inv = synced_inv_source_node.inv
		slot.mirrored_hud_slot = hotbar_hud_grid.get_child(i)
		slots.append(slot)
		i += 1

## Sets up the trash slot with its needed data. It is considered a core slot and is tracked by the
## inventory resource.
func _setup_trash_slot() -> void:
	trash_slot.name = "Trash_Slot"
	trash_slot.index = assign_next_slot_index(true)
	trash_slot.synced_inv = synced_inv_source_node.inv
	trash_slot.is_trash_slot = true
	slots.append(trash_slot)

## Checks when we open and close the player inventory based on certain key inputs.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("player_inventory"):
		is_open = not is_open
	elif event.is_action_pressed("esc"):
		is_open = false
	elif event.is_action_pressed("interact"):
		if is_open:
			is_open = false
			accept_event() # Otherwise it just reopens it again after an external open request

	# If we are dragging when we press any key, end the drag.
	if get_viewport().gui_is_dragging():
		var drag_end_event: InputEventMouseButton = InputEventMouseButton.new()
		drag_end_event.button_index = MOUSE_BUTTON_LEFT
		drag_end_event.position = position
		drag_end_event.pressed = false
		Input.parse_input_event(drag_end_event)

## Handles the opening and closing of the entire player inventory based on the is_open var.
func _toggle_inventory_ui(new_value: bool) -> void:
	is_open = new_value
	visible = new_value
	Globals.ui_focus_open = is_open
	if not is_open:
		side_panel_active = false
	Globals.change_focused_ui_state(is_open)

## Handles the opening and closing of the side panel based on the value of the side_panel_active var.
func _toggle_side_panel(new_value: bool) -> void:
	side_panel_active = new_value
	side_panel_mgr.delete(not new_value)
	crafting_manager.visible = not side_panel_active
	wearables_panel.visible = not side_panel_active

## When a side panel wants to open, open the inventory screen with the side panel active.
func open_with_side_panel() -> void:
	is_open = true
	side_panel_active = true

#region Dropping On Ground
## When we click the empty space around this player inventory, change needed visibilities.
func _on_blank_space_input_event(event: InputEvent) -> void:
	if event.is_action_released("primary"):
		is_open = false
		accept_event()

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

		if ground_item_res is ProjAmmoResource:
			synced_inv_source_node.hands.active_slot_info.calculate_inv_ammo()

	data._on_mouse_exited()
#endregion

#region Buttons
## Activates sorting this inventory by name.
func _on_sort_by_name_btn_pressed() -> void:
	Globals.player_node.inv.activate_sort_by_name()
func _on_sort_by_name_btn_button_down() -> void:
	sort_by_name_btn.texture = btn_down_texture
func _on_sort_by_name_btn_button_up() -> void:
	sort_by_name_btn.texture = btn_up_texture

## Activates sorting this inventory by rarity.
func _on_sort_by_rarity_btn_pressed() -> void:
	Globals.player_node.inv.activate_sort_by_rarity()
func _on_sort_by_rarity_btn_button_down() -> void:
	sort_by_rarity_btn.texture = btn_down_texture
func _on_sort_by_rarity_btn_button_up() -> void:
	sort_by_rarity_btn.texture = btn_up_texture

## Activates sorting this inventory by count.
func _on_sort_by_type_btn_pressed() -> void:
	Globals.player_node.inv.activate_sort_by_type()
func _on_sort_by_type_btn_button_down() -> void:
	sort_by_type_btn.texture = btn_down_texture
func _on_sort_by_type_btn_button_up() -> void:
	sort_by_type_btn.texture = btn_up_texture

## Activates auto-stacking this inventory.
func _on_auto_stack_btn_pressed() -> void:
	Globals.player_node.inv.activate_auto_stack()
func _on_auto_stack_btn_button_down() -> void:
	auto_stack_btn.texture = btn_down_texture
func _on_auto_stack_btn_button_up() -> void:
	auto_stack_btn.texture = btn_up_texture

## Attempts to craft whatever is shown in the output slot of the crafting UI.
func _on_craft_btn_pressed() -> void:
	get_node("%CraftingManager").attempt_craft()
func _on_craft_btn_button_down() -> void:
	craft_btn.texture = btn_down_texture
func _on_craft_btn_button_up() -> void:
	craft_btn.texture = btn_up_texture

## Showing and hiding sort & stack tooltips.
func _on_sort_btn_mouse_entered(sort_method: String) -> void:
	CursorManager.update_tooltip("Sort by " + sort_method)
func _on_autostack_btn_mouse_entered() -> void:
	CursorManager.update_tooltip("Autostack Items")
func _on_craft_btn_mouse_entered() -> void:
	CursorManager.update_tooltip("Craft")
func _hide_tooltip() -> void:
	CursorManager.hide_tooltip()
#endregion
