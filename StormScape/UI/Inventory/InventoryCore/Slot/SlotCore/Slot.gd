@icon("res://Utilities/Debug/EditorIcons/slot.svg")
extends NinePatchRect
class_name Slot
## The item and quantity representation inside all inventories. Handles drag and drop logic as well as stacking.

signal item_changed(slot: Slot, old_item: InvItemResource, new_item: InvItemResource) ## Emitted when the item in the slot is changed or set.

static var hovered_slot_size: float = 22.0 ## The size of the hovered over slot used to conditionally center the drag preview when scaling is messed up. 22 comes from the normally-sized inventory slots.

@export var default_slot_texture: Texture2D ## The default texture of the slot with an item in it.
@export var no_item_slot_texture: Texture2D ## The texture of the slot with no item when it is selected or active.
@export var backing_texture: Texture2D ## The texture of the slot that appears behind everything else.
@export var preview_only: bool = false ## When true, this slot will not react to drags or hovers.

@onready var texture_margins: MarginContainer = $TextureMargins ## The item texture margins node for this slot.
@onready var back_color: ColorRect = $BackColorMargin/BackColor ## The color behind the item.
@onready var item_texture: TextureRect = $TextureMargins/ItemTexture ## The item texture node for this slot.
@onready var quantity: Label = $QuantityMargins/Quantity ## The quantity label for this slot.
@onready var rarity_glow: TextureRect = $RarityGlowMargin/RarityGlow ## The glow behind the weapon in the slot.
@onready var selected_texture: TextureRect = $SelectedTexture ## The texture that appears when this slot is selected or active.
@onready var backing_texture_rect: TextureRect = $BackingTextureMargin/BackingTexture ## The texture rect that appears behind everything as an icon.
@onready var corner_info_icons_margin: MarginContainer = $CornerInfoIconsMargin ## The margins for the corner info.
@onready var corner_info_icons_grid: HBoxContainer = %CornerInfoIconsHBox ## The grid holding the corner info icons.
@onready var modded_icon: TextureRect = %ModdedIcon ## The icon that shows up on a weapon if it is modded.

var index: int ## The index that this slot represents inside the inventory.
var synced_inv: InventoryResource ## The synced inventory that this slot is a part of.
var drag_preview: PackedScene = preload("res://UI/Inventory/InventoryCore/Slot/SlotCore/SlotDragPreview.tscn") ## The control preview for a dragged slot.
var dragging_only_one: bool = false ## Whether this slot is carrying only a quantity of 1 when in drag data.
var dragging_half_stack: bool = false ## Whether this slot is carrying only half of its quantity when in drag data.
var item: InvItemResource: set = set_item ## The current inventory item represented in this slot.
var is_hud_ui_preview_slot: bool = false ## Whether this slot is an inventory hotbar preview slot for the player's screen.
var is_trash_slot: bool = false ## The slot, that if present, is used to discard items. It will have the highest index.
var is_hotbar_slot: bool = false ## When true, this slot is being used as a hotbar slot.
var tint_tween: Tween = null ## The tween animating the tint progress.
var tint_progress: float = 100.0: ## How much of the tint should be filled upwards. Runs from 0 - 100.
	set(new_value):
		tint_progress = new_value
		back_color.set_instance_shader_parameter("progress", new_value)
var pause_changed_signals: bool = false ## When true, the item_changed signal will not be emitted by the setter. Useful for when the slot itself is making changes like when the slot quantity limit is only 1 and we have to send extra quantities back out.
var preview_items: Array[Dictionary] = []: ## When this isn't null, this items will display as a cycling preview and nothing will be able to be dragged out of this slot.
	set(new_preview_items):
		preview_items = new_preview_items
		if not preview_items.is_empty():
			_update_visuals(preview_items[0])
			preview_cycle_timer.start()
		else:
			preview_cycle_timer.stop()
			_update_visuals({ item : -1 })
var preview_cycle_timer: Timer = TimerHelpers.create_repeating_timer(self, 2.25, _on_preview_cycle_timer_timeout)
var mirrored_hud_slot: Slot ## When not null, any item changes to this slot will also send changes to this HUD slot. Useful for the hotbar where there are two sets of distinct slots that need to stay connected. This doesn't mirror preview arrays.


## Setter function for the item represented by this slot. Updates texture and quantity label.
func set_item(new_item: InvItemResource) -> void:
	if not preview_items.is_empty():
		if new_item != null:
			preview_items = []

	var old_item: InvItemResource = item
	item = new_item

	_update_visuals({ new_item : -1 })

	if item != null and item.quantity <= 0:
		item = null

	if not pause_changed_signals:
		item_changed.emit(self, old_item, item)

	if mirrored_hud_slot:
		mirrored_hud_slot.set_item(new_item)

	if index < synced_inv.total_inv_size:
		synced_inv.inv[index] = new_item

## Connects relevant mouse entered and exited functions.
func _ready() -> void:
	if backing_texture != null:
		backing_texture_rect.texture = backing_texture
	rarity_glow.hide()
	selected_texture.hide()
	item_texture.material.set_shader_parameter("highlight_strength", 0.0)
	texture_margins.pivot_offset = texture_margins.size / 2

	var texture_margins_ratio: float = texture_margins.size.x / 22.0
	var margin_size: int = (ceili(int(3 * texture_margins_ratio)))
	texture_margins.add_theme_constant_override("margin_bottom", margin_size)
	texture_margins.add_theme_constant_override("margin_top", margin_size)
	texture_margins.add_theme_constant_override("margin_left", margin_size)
	texture_margins.add_theme_constant_override("margin_right", margin_size)

	var corner_icon_size: float = 3.25 * texture_margins_ratio
	for icon: TextureRect in corner_info_icons_grid.get_children():
		icon.custom_minimum_size = Vector2(corner_icon_size, corner_icon_size)
	corner_info_icons_grid.add_theme_constant_override("separation", 1 if texture_margins.size.x <= 30.0 else 3)
	corner_info_icons_margin.add_theme_constant_override("margin_left", max(1, floori(int(2 * texture_margins_ratio))))
	corner_info_icons_margin.add_theme_constant_override("margin_top", max(1, floori(int(2 * texture_margins_ratio))))

	var margins: int = texture_margins.get_theme_constant("margin_bottom") * 2
	item_texture.size = texture_margins.size - Vector2(margins, margins) # Using the texture margins minus its margin amount to get the item texture size since it doesn't update immediately at game start
	item_texture.pivot_offset = item_texture.size / 2

	if not preview_only:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		visibility_changed.connect(_on_visibility_changed)

	_reset_corner_icons()

#region Visuals
## Updates the slot visuals according to the new item.
func _update_visuals(new_item_dict: Dictionary) -> void:
	var new_item: InvItemResource = new_item_dict.keys()[0]

	_reset_corner_icons()
	update_corner_icons(new_item)

	if new_item and new_item.quantity > 0:
		var new_item_rarity: int = new_item_dict.values()[0] if new_item_dict.values()[0] != -1 else new_item.stats.rarity

		update_tint_progress(Globals.player_node.inv.auto_decrementer.get_cooldown(new_item.stats.get_cooldown_id()))

		item_texture.texture = new_item.stats.inv_icon

		texture_margins.rotation_degrees = new_item.stats.inv_icon_rotation
		texture_margins.scale = new_item.stats.inv_icon_scale
		texture_margins.position = new_item.stats.inv_icon_offset * (item_texture.size / 16.0)

		rarity_glow.self_modulate = Globals.rarity_colors.slot_glow.get(new_item_rarity)
		rarity_glow.show()

		back_color.set_instance_shader_parameter("main_color", Globals.rarity_colors.slot_fill.get(new_item_rarity))

		if new_item_rarity in [Globals.ItemRarity.EPIC, Globals.ItemRarity.LEGENDARY, Globals.ItemRarity.SINGULAR]:
			var gradient_texture: GradientTexture1D = GradientTexture1D.new()
			gradient_texture.gradient = Gradient.new()
			gradient_texture.gradient.add_point(0, Globals.rarity_colors.glint_color.get(new_item_rarity))
			item_texture.material.set_shader_parameter("color_gradient", gradient_texture)
			item_texture.material.set_shader_parameter("highlight_strength", 0.4)
		else:
			item_texture.material.set_shader_parameter("highlight_strength", 0.0)

		quantity.self_modulate.a = 1.0

		if not preview_items.is_empty():
			var outline_width: float = (0.5 * (max(item_texture.texture.get_width() / new_item.stats.inv_icon_scale.x, item_texture.texture.get_height() / new_item.stats.inv_icon_scale.y) / 16.0))
			if new_item_dict.values()[0] != 0:
				item_texture.material.set_shader_parameter("width", outline_width)
				item_texture.material.set_shader_parameter("outline_color", Globals.rarity_colors.outline_color.get(new_item_dict.values()[0]))
			else:
				item_texture.material.set_shader_parameter("width", 0.0)

			back_color.hide()
			quantity.self_modulate.a = 0.72
			item_texture.set_instance_shader_parameter("final_alpha", 0.88)
		else:
			if new_item.quantity > 1:
				quantity.text = str(new_item.quantity)
			else:
				quantity.text = ""

			item_texture.material.set_shader_parameter("width", 0.0)
			back_color.show()
			quantity.self_modulate.a = 1.0
			item_texture.set_instance_shader_parameter("final_alpha", 1.0)
	else:
		update_tint_progress(0)
		item_texture.texture = null
		quantity.text = ""
		quantity.self_modulate.a = 1.0
		rarity_glow.hide()
		back_color.hide()
		texture_margins.rotation = 0
		texture_margins.position = Vector2.ZERO
		texture_margins.scale = Vector2.ONE
		item_texture.set_instance_shader_parameter("final_alpha", 1.0)

## When the preview cycle delay timer ends, show the next preview item if there are any.
func _on_preview_cycle_timer_timeout() -> void:
	if preview_items.is_empty():
		preview_cycle_timer.stop()
		return

	var first_in_queue: Dictionary = preview_items.pop_front()
	preview_items.append(first_in_queue)
	_update_visuals(preview_items[0])

## Hides all corner icons for this slot.
func _reset_corner_icons() -> void:
	for icon: TextureRect in corner_info_icons_grid.get_children():
		icon.hide()

## Conditionally shows the needed corner icons.
func update_corner_icons(new_item: InvItemResource) -> void:
	if new_item == null:
		return

	if new_item.stats is WeaponResource:
		if new_item.stats.has_any_mods():
			modded_icon.show()
		else:
			modded_icon.hide()

## When this is shown or hidden and different slots are displayed, update the local tint progress
## with the current item.
func _on_visibility_changed() -> void:
	await get_tree().process_frame
	update_tint_progress(Globals.player_node.inv.auto_decrementer.get_cooldown(item.stats.get_cooldown_id()) if item != null else 0.0)

## Updates the upwards fill tinting that represents an item on cooldown.
func update_tint_progress(duration: float) -> void:
	if duration > 0 and item != null:
		var cooldown_source: String = Globals.player_node.inv.auto_decrementer.get_cooldown_source_title(item.stats.get_cooldown_id())
		if cooldown_source not in item.stats.shown_cooldown_fills:
			return

		if tint_tween: tint_tween.kill()
		tint_progress = (1 - (duration / Globals.player_node.inv.auto_decrementer.get_original_cooldown(item.stats.get_cooldown_id()))) * 100
		if not Globals.focused_ui_is_open:
			tint_tween = create_tween()
			tint_tween.tween_property(self, "tint_progress", 100.0, duration)
	else:
		tint_progress = 100.0

## Resets slot highlights and drag preview effects.
func _reset_post_drag_mods() -> void:
	dragging_only_one = false
	dragging_half_stack = false
	modulate = Color(1, 1, 1, 1)
	if item == null:
		if preview_items.is_empty():
			item_texture.texture = null
			texture_margins.rotation = 0
			texture_margins.position = Vector2.ZERO
			texture_margins.scale = Vector2.ONE
	else:
		var slash_index: int = quantity.text.rfind("/")
		if slash_index != -1 and item.quantity > 0:
			quantity.text = str(item.quantity) + "/" + quantity.text.substr(slash_index + 1, quantity.text.length())
		elif item.quantity > 1:
			quantity.text = str(item.quantity)
	item_texture.modulate.a = 1.0
#endregion

#region Regular Drags
## Gets a reference to the data from the slot where the drag originated.
func _get_drag_data(at_position: Vector2) -> Variant:
	if not preview_items.is_empty(): # Don't allow drags out of this slot if it is showing a preview item
		return null

	dragging_half_stack = false
	dragging_only_one = false
	if item != null and not is_hud_ui_preview_slot:
		modulate = Color(0.65, 0.65, 0.65, 1)
		var slash_index: int = quantity.text.rfind("/")
		if slash_index != -1:
			quantity.text = "0/" + quantity.text.substr(slash_index + 1, quantity.text.length())
		else:
			quantity.text = ""
		item_texture.modulate.a = 0.65
		set_drag_preview(_make_drag_preview(at_position))
		return self
	else:
		return null

## Creates a drag preview to display at the mouse when a drag is in progress.
func _make_drag_preview(at_position: Vector2) -> Control:
	var c: Control = Control.new()
	if item and item.stats.inv_icon and item.quantity > 0:
		var preview_scene: Control = drag_preview.instantiate()
		var preview_tex_margins: MarginContainer = preview_scene.get_node("TextureMargins")
		var preview_texture: TextureRect = preview_tex_margins.get_node("ItemTexture")

		preview_texture.texture = item.stats.inv_icon

		preview_tex_margins.rotation_degrees = item.stats.inv_icon_rotation
		preview_tex_margins.position = item.stats.inv_icon_offset * (item_texture.size / 16.0)
		preview_tex_margins.scale = item.stats.inv_icon_scale

		var outline_width: float = (0.5 * (max(item_texture.texture.get_width() / item.stats.inv_icon_scale.x, item_texture.texture.get_height() / item.stats.inv_icon_scale.y) / 16.0))

		preview_texture.material.set_shader_parameter("width", outline_width)
		preview_texture.material.set_shader_parameter("highlight_strength", 0.0)
		preview_texture.material.set_shader_parameter("outline_color", Globals.rarity_colors.outline_color.get(item.stats.rarity))

		if dragging_only_one:
			preview_scene.get_node("QuantityMargins/Quantity").text = ""
		elif dragging_half_stack:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(int(floor(item.quantity / 2.0)))
		else:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(item.quantity) if item.quantity > 1 else ""

		if Slot.hovered_slot_size > 22:
			preview_scene.position = -Vector2(22.0 / 2.0, 22.0 / 2.0)
		else:
			preview_scene.position = -at_position

		c.add_child(preview_scene)
	return c
#endregion

#region RightClick Drags
## When a right click drag is released, interpret it as a left click drag.
## Allows right drags to work with Godot's drag system.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			if get_viewport().gui_is_dragging():
				event = event.duplicate()
				event.button_index = MOUSE_BUTTON_LEFT
				Input.parse_input_event(event)

## When we start a right click drag, interpret it as starting a left click drag.
## Runs single quantity and half quantity logic.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if item != null:
				var slash_index: int = quantity.text.rfind("/")
				if Input.is_action_pressed("sprint") and item.quantity > 1:
					dragging_half_stack = true
					if slash_index != -1:
						quantity.text = str(item.quantity - int(floor(item.quantity / 2.0))) + "/" + quantity.text.substr(slash_index + 1, quantity.text.length())
					else:
						quantity.text = str(item.quantity - int(floor(item.quantity / 2.0)))
				else:
					if item.quantity - 1 > 0:
						dragging_only_one = true
						if slash_index != -1:
							quantity.text = str(item.quantity - 1) + "/" + quantity.text.substr(slash_index + 1, quantity.text.length())
						else:
							quantity.text = str(item.quantity - 1)
					else:
						if slash_index != -1:
							quantity.text = "0/" + quantity.text.substr(slash_index + 1, quantity.text.length())
						else:
							quantity.text = ""
						item_texture.modulate.a = 0.65
				modulate = Color(0.65, 0.65, 0.65, 1)

				force_drag(self, _make_drag_preview(get_local_mouse_position()))
		elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			if item != null:
				_fill_slot_to_stack_size()
#endregion

## Determines if the slot we are hovering over during a drag can accept drag data on mouse release.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data.item == null or not synced_inv or is_same_slot_as(data) or is_hud_ui_preview_slot:
		return false
	elif data is WearableSlot or data is ModSlot:
		if item != null and not (item.stats.is_same_as(data.item.stats) and item.quantity < item.stats.stack_size):
			if not is_trash_slot:
				return false
	return true

## Drops item slot drag data into the hovered slot, updating the current and source
## slot based on quantities and drag method.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data and synced_inv):
		return

	if item == null:
		if data.dragging_only_one:
			_move_one_item_to_empty_slot(data)
			data.dragging_only_one = false
		elif data.dragging_half_stack:
			var total_quantity: int = int(floor(data.item.quantity / 2.0))
			var source_remainder: int = data.item.quantity - total_quantity
			_move_all_of_the_half_stack_into_a_slot(data, source_remainder, total_quantity)
			data.dragging_half_stack = false
		else:
			_move_items_to_other_empty_slot(data)
	else:
		if item.stats.is_same_as(data.item.stats):
			if data.dragging_only_one:
				var total_quantity: int = item.quantity + 1
				if total_quantity <= item.stats.stack_size:
					_add_one_item_into_slot_with_space(data, total_quantity)
				data.dragging_only_one = false
			elif data.dragging_half_stack:
				var total_quantity: int = int(floor(data.item.quantity / 2.0)) + item.quantity
				var source_remainder: int = data.item.quantity - int(floor(data.item.quantity / 2.0))
				if total_quantity <= item.stats.stack_size:
					_move_all_of_the_half_stack_into_a_slot(data, source_remainder, total_quantity)
				else:
					_move_part_of_half_stack_into_slot_and_leave_remainder(data)
				data.dragging_half_stack = false
			else:
				var total_quantity: int = item.quantity + data.item.quantity
				if total_quantity <= item.stats.stack_size:
					_combine_all_items_into_slot_with_space(data, total_quantity)
				else:
					_combine_what_fits_and_leave_remainder(data)
		elif not data.dragging_only_one and not data.dragging_half_stack:
			_swap_item_stacks(data)
		else:
			if data.dragging_only_one:
				_replace_with_one_item_and_find_available_slot_for_previous_stuff(data)
			elif data.dragging_half_stack:
				var total_quantity: int = int(floor(data.item.quantity / 2.0))
				var source_remainder: int = data.item.quantity - total_quantity
				_replace_with_half_stack_and_find_available_slot_for_previous_stuff(data, source_remainder, total_quantity)

	await get_tree().process_frame
	_on_mouse_entered()

#region Dropping Full Stacks
## Moves all items from drag into a different empty slot.
func _move_items_to_other_empty_slot(data: Variant) -> void:
	set_item(InvItemResource.new(data.item.stats, data.item.quantity))
	data.set_item(null)

## Combines the drag data items into a slot with items of the same kind. This means that when
## combined they still fit stack size.
func _combine_all_items_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	set_item(item)
	data.set_item(null)

## Combines items of same kind from drag data into an already occupied slot. Passes what doesn't
## fit to the next iteration.
func _combine_what_fits_and_leave_remainder(data: Variant) -> void:
	var amount_that_fits: int = item.stats.stack_size - item.quantity
	item.quantity = item.stats.stack_size
	set_item(item)

	if is_trash_slot:
		if not data.dragging_half_stack:
			data.set_item(null)
		else:
			var new_item: InvItemResource = InvItemResource.new(data.item.stats, data.item.quantity - int(floor(data.item.quantity / 2.0)))
			data.set_item(new_item)
	else:
		var new_item: InvItemResource = InvItemResource.new(data.item.stats, data.item.quantity - amount_that_fits)
		data.set_item(new_item)

## Swaps the items in the slots.
func _swap_item_stacks(data: Variant) -> void:
	var temp_item: InvItemResource = item
	set_item(InvItemResource.new(data.item.stats, data.item.quantity))

	if is_trash_slot:
		data.set_item(null)
	else:
		data.set_item(temp_item)
#endregion

#region Dropping Only One
## Moves a quantity of 1 from an item slot to an empty slot.
func _move_one_item_to_empty_slot(data: Variant) -> void:
	set_item(InvItemResource.new(data.item.stats, 1))
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

## Moves a quantity of 1 from the drag data into a slot of the same kind with space.
func _add_one_item_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	set_item(item)
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

## Drops the single item into the new slot and finds an available spot for the items that used to be in that spot.
func _replace_with_one_item_and_find_available_slot_for_previous_stuff(data: Variant) -> void:
	var temp_item: InvItemResource = item
	set_item(InvItemResource.new(data.item.stats, 1))
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

	if not is_trash_slot:
		synced_inv.insert_from_inv_item(temp_item, false, false)

## After moving a quantity of 1 in any way, checks that the source did not only have 1 to
## begin with and would then need to be cleared out.
func _check_if_inv_slot_is_now_empty_after_dragging_only_one(data: Variant) -> void:
	if data.item.quantity < 2:
		data.set_item(null)
	else:
		data.set_item(InvItemResource.new(data.item.stats, data.item.quantity - 1))
#endregion

#region Dropping Half Stacks
## Moves all of the half quantity represented by the drag data into a slot with space, empty or not.
func _move_all_of_the_half_stack_into_a_slot(data: Variant, source_remainder: int, total_quantity: int) -> void:
	set_item(InvItemResource.new(data.item.stats, total_quantity))
	data.set_item(InvItemResource.new(data.item.stats, source_remainder))

## Moves what fits from the half quantity represented by the drag data into a slot that can take some of it.
## Leaves what doesn't fit.
func _move_part_of_half_stack_into_slot_and_leave_remainder(data: Variant) -> void:
	_combine_what_fits_and_leave_remainder(data)

## Drops the half stack into the new slot and finds an available spot for the items that used to be in that spot.
func _replace_with_half_stack_and_find_available_slot_for_previous_stuff(data: Variant, source_remainder: int,
																			total_quantity: int) -> void:
	var temp_item: InvItemResource = item
	set_item(InvItemResource.new(data.item.stats, total_quantity))

	if not is_trash_slot:
		synced_inv.insert_from_inv_item(temp_item, false, false)

	data.set_item(InvItemResource.new(data.item.stats, source_remainder))
#endregion

#region Double Clicks
## When an item is double clicked in the inventory, attempt to garner a full stack by iterating
## over all other slots.
## Pulls from slots not at stack size first, then goes back and gets from stack size if needed.
func _fill_slot_to_stack_size() -> void:
	if item == null:
		return

	var full_stack_size: int = item.stats.stack_size
	var needed_quantity: int = full_stack_size - item.quantity
	if needed_quantity <= 0:
		return

	# First pass: pull items from slots that are not full
	for i: int in range(synced_inv.main_inv_size):
		if i == index:
			continue

		var donor: InvItemResource = synced_inv.inv[i]
		if donor != null and donor.stats.is_same_as(item.stats) and donor.quantity < donor.stats.stack_size:
			var transfer_amount: int = min(needed_quantity, donor.quantity)
			item.quantity += transfer_amount
			donor.quantity -= transfer_amount
			needed_quantity -= transfer_amount

			# If the donor slot has been completely emptied, update it to null
			if donor.quantity <= 0:
				donor = null

			synced_inv.inv[i] = donor
			synced_inv.inv_data_updated.emit(i, donor)

			if needed_quantity <= 0:
				break

	# Second pass: if more items are needed, pull from all matching slots (even from full stacks)
	if needed_quantity > 0:
		for i: int in range(synced_inv.main_inv_size):
			if i == index:
				continue

			var donor: InvItemResource = synced_inv.inv[i]
			if donor != null and donor.stats.is_same_as(item.stats):
				var transfer_amount: int = min(needed_quantity, donor.quantity)
				item.quantity += transfer_amount
				donor.quantity -= transfer_amount
				needed_quantity -= transfer_amount

				if donor.quantity <= 0:
					donor = null

				synced_inv.inv[i] = donor
				synced_inv.inv_data_updated.emit(i, donor)

				if needed_quantity <= 0:
					break

	set_item(item)
#endregion

#region Utils
## When mouse enters, if we can drop, display an effect on this slot. Also stop previews temporarily if they are
## in progress.
func _on_mouse_entered() -> void:
	Slot.hovered_slot_size = size.x

	if get_viewport().gui_is_dragging():
		if not preview_items.is_empty():
			preview_cycle_timer.stop()
			quantity.self_modulate.a = 0.0
			rarity_glow.hide()

		var drag_data: Variant = get_viewport().gui_get_drag_data()
		if _can_drop_data(get_local_mouse_position(), drag_data):
			modulate = Color(1.2, 1.2, 1.2, 1.0)

			if item == null:
				item_texture.texture = drag_data.item_texture.texture
				texture_margins.rotation_degrees = drag_data.item.stats.inv_icon_rotation
				texture_margins.position = drag_data.item.stats.inv_icon_offset * (item_texture.size / 16.0)
				texture_margins.scale = drag_data.item.stats.inv_icon_scale
				item_texture.set_instance_shader_parameter("final_alpha", 0.75)

				item_texture.material.set_shader_parameter("width", 0)

	SignalBus.slot_hovered.emit(self)

## When mouse exits, if we are dragging, remove effects on this slot. If we have queued previews, resume them.
func _on_mouse_exited() -> void:
	SignalBus.slot_not_hovered.emit()

	var drag_data: Variant
	if get_viewport().gui_is_dragging():
		drag_data = get_viewport().gui_get_drag_data()
		if drag_data is Slot and is_same_slot_as(drag_data):
			return

	modulate = Color(1, 1, 1, 1)

	if item == null and drag_data:
		item_texture.texture = null
		texture_margins.rotation = 0
		texture_margins.position = Vector2.ZERO
		texture_margins.scale = Vector2.ONE
		item_texture.set_instance_shader_parameter("final_alpha", 1.0)

	if not preview_items.is_empty():
		_update_visuals(preview_items[0])
		preview_cycle_timer.start()

## When the system is notifed of a drag being over, call the method that resets slot highlight and
## drag preview effects.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_reset_post_drag_mods()

## Returns true if this slot and the passed in slot have the same index and the same synced inventory.
func is_same_slot_as(other_slot: Slot) -> bool:
	if (self.index == other_slot.index) and (self.synced_inv == other_slot.synced_inv):
		return true
	return false

## Custom string representation of the item in this slot.
func _to_string() -> String:
	return str(item)
#endregion
