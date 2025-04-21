@icon("res://Utilities/Debug/EditorIcons/inventory_ui.svg")
extends InventoryUI
class_name PlayerInvUI
## An child class of the inventory UI that adds functions specific to the player inventory.

@export_group("Connections")
@export var hotbar_grid: HBoxContainer ## The container that holds the hotbar slots.
@export var hotbar_hud_grid: HBoxContainer ## The container that holds the HUD-only hotbar slots.
@export var trash_slot: Slot ## The trash slot.
@export var item_details_panel: ItemDetailsPanel ## The item viewer in the inventory.
@export var crafting_manager: CraftingManager ## The crafting manager panel.
@export var wearables_panel: WearablesPanel ## The wearables panel.
@export var alternate_inv_panel: VBoxContainer ## The panel that fills with alternate inventories like chests.

@export_group("Textures")
@export var btn_up_texture: Texture2D ## The texture for buttons when not pressed.
@export var btn_down_texture: Texture2D ## The texture for buttons when pressed.

@onready var sort_by_name: NinePatchRect = %SortByName ## The sort by name button.
@onready var sort_by_type: NinePatchRect = %SortByType ## The sort by type button.
@onready var sort_by_rarity: NinePatchRect = %SortByRarity ## The sort by rarity button.
@onready var auto_stack: NinePatchRect = %AutoStack ## The autostacking button.
@onready var craft: NinePatchRect = %Craft ## The craft button.
@onready var alternate_inv_title: Label = %AlternateInvTitle ## The title label of the alternate side inventory.

var is_open: bool = false: ## True when the inventory is open and showing.
	set(new_value):
		is_open = new_value
		visible = new_value
		Globals.player_inv_is_open = is_open
		Globals.change_focused_ui_state(is_open)
		if not is_open:
			showing_alternate_inv = false
var showing_alternate_inv: bool = false: ## When true, the alternate inv is open and the wearable & crafting panels should be hidden.
	set(new_value):
		showing_alternate_inv = new_value
		if showing_alternate_inv:
			alternate_inv_panel.visible = true
			crafting_manager.visible = false
			wearables_panel.visible = false
		else:
			alternate_inv_panel.visible = false


func _ready() -> void:
	super()
	gui_input.connect(_on_blank_space_input_event)
	SignalBus.alternate_inv_open_request.connect(_on_alternate_inv_open_request)

	_setup_hotbar_slots()
	_setup_trash_slot()

## Sets up the in-inventory hotbar slots with their needed data. They are considered core slots and tracked by
## the inventory resource.
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
		if not is_open:
			_open_player_inv()
		else:
			is_open = false
	elif event.is_action_pressed("esc"):
		is_open = false
	elif event.is_action_pressed("interact"):
		if is_open:
			is_open = false
			accept_event() # Otherwise it just reopens it again

	# If we are dragging when we press any key, end the drag.
	if get_viewport().gui_is_dragging():
		var drag_end_event: InputEventMouseButton = InputEventMouseButton.new()
		drag_end_event.button_index = MOUSE_BUTTON_LEFT
		drag_end_event.position = position
		drag_end_event.pressed = false
		Input.parse_input_event(drag_end_event)

## Opens the player inventory, conditionally showing the crafting manager and wearables panel.
func _open_player_inv() -> void:
	is_open = true
	if not showing_alternate_inv:
		crafting_manager.visible = true
		wearables_panel.visible = true

## When an alternate inventory wants to open, tell the alternate inv panel and open the inventory if possible.
func _on_alternate_inv_open_request(alternate_inv_source_node: Node2D) -> void:
	alternate_inv_panel.link_new_inventory_source_node(alternate_inv_source_node)
	alternate_inv_title.text = alternate_inv_source_node.inv.title
	showing_alternate_inv = true
	_open_player_inv()

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
	sort_by_name.texture = btn_down_texture
func _on_sort_by_name_btn_button_up() -> void:
	sort_by_name.texture = btn_up_texture

## Activates sorting this inventory by rarity.
func _on_sort_by_rarity_btn_pressed() -> void:
	Globals.player_node.inv.activate_sort_by_rarity()
func _on_sort_by_rarity_btn_button_down() -> void:
	sort_by_rarity.texture = btn_down_texture
func _on_sort_by_rarity_btn_button_up() -> void:
	sort_by_rarity.texture = btn_up_texture

## Activates sorting this inventory by count.
func _on_sort_by_type_btn_pressed() -> void:
	Globals.player_node.inv.activate_sort_by_type()
func _on_sort_by_type_btn_button_down() -> void:
	sort_by_type.texture = btn_down_texture
func _on_sort_by_type_btn_button_up() -> void:
	sort_by_type.texture = btn_up_texture

## Activates auto-stacking this inventory.
func _on_auto_stack_btn_pressed() -> void:
	Globals.player_node.inv.activate_auto_stack()
func _on_auto_stack_btn_button_down() -> void:
	auto_stack.texture = btn_down_texture
func _on_auto_stack_btn_button_up() -> void:
	auto_stack.texture = btn_up_texture

## Attempts to craft whatever is shown in the output slot of the crafting UI.
func _on_craft_btn_pressed() -> void:
	get_node("%CraftingManager").attempt_craft()
func _on_craft_btn_button_down() -> void:
	craft.texture = btn_down_texture
func _on_craft_btn_button_up() -> void:
	craft.texture = btn_up_texture
#endregion
