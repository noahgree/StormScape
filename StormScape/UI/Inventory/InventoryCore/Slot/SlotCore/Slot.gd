@tool
extends NinePatchRect
class_name Slot
## The item and quantity representation inside all inventories. Handles drag and drop logic as well as stacking.

signal item_changed(slot: Slot, old_item: InvItemResource, new_item: InvItemResource)
signal is_hovered_over(index: int) ## Emitted when a slot is currently being hovered over.
signal is_not_hovered_over ## Emitted when a slot is no longer being hovered over.

static var hovered_slot_size: float = 22.0 ## The size of the hovered over slot used to conditionally center the drag preview when scaling is messed up. 22 comes from the normally-sized inventory slots.

@export var drag_preview: PackedScene = preload("res://UI/Inventory/InventoryCore/Slot/SlotCore/SlotDragPreview.tscn") ## The control preview for a dragged slot.
@export var default_slot_texture: Texture2D ## The default texture of the slot with an item in it.
@export var no_item_slot_texture: Texture2D ## The texture of the slot with no item when it is selected or active.
@export var backing_texture: Texture2D ## The texture of the slot that appears behind everything else.

@onready var texture_margins: MarginContainer = $TextureMargins ## The item texture margins node for this slot.
@onready var back_color: ColorRect = $BackColorMargin/BackColor ## The color behind the item.
@onready var item_texture: TextureRect = $TextureMargins/ItemTexture ## The item texture node for this slot.
@onready var quantity: Label = $QuantityMargins/Quantity ## The quantity label for this slot.
@onready var rarity_glow: TextureRect = $RarityGlowMargin/RarityGlow ## The glow behind the weapon in the slot.
@onready var selected_texture: TextureRect = $SelectedTexture ## The texture that appears when this slot is selected or active.
@onready var backing_texture_rect: TextureRect = $BackingTextureMargin/BackingTexture ## The texture rect that appears behind everything as an icon.

var index: int ## The index that this slot represents inside the inventory.
var synced_inv: Inventory ## The synced inventory that this slot is a part of.
var dragging_only_one: bool = false ## Whether this slot is carrying only a quantity of 1 when in drag data.
var dragging_half_stack: bool = false ## Whether this slot is carrying only half of its quantity when in drag data.
var item: InvItemResource: set = _set_item ## The current inventory item represented in this slot.
var is_hud_ui_preview_slot: bool = false ## Whether this slot is an inventory hotbar preview slot for the player's screen.
var is_trash_slot: bool = false ## The slot, that if present, is used to discard items. It will have the highest index.
var tint_tween: Tween = null ## The tween animating the tint progress.
var tint_progress: float = 100.0: ## How much of the tint should be filled upwards. Runs from 0 - 100.
	set(new_value):
		tint_progress = new_value
		back_color.set_instance_shader_parameter("progress", new_value)


## Setter function for the item represented by this slot. Updates texture and quantity label.
func _set_item(new_item: InvItemResource) -> void:
	var old_item: InvItemResource = item
	item = new_item

	if item and item.quantity > 0:
		update_tint_progress(GlobalData.player_node.inv.auto_decrementer.get_cooldown(item.stats.get_cooldown_id()))

		item_texture.texture = item.stats.inv_icon

		back_color.set_instance_shader_parameter("main_color", GlobalData.rarity_colors.slot_fill.get(item.stats.rarity))
		back_color.show()

		item_texture.material.set_shader_parameter("width", 0.0)

		texture_margins.rotation_degrees = item.stats.inv_icon_rotation
		texture_margins.position = item.stats.inv_icon_offset * (item_texture.size / item_texture.custom_minimum_size)
		texture_margins.scale = item.stats.inv_icon_scale

		rarity_glow.self_modulate = GlobalData.rarity_colors.slot_glow.get(item.stats.rarity)
		rarity_glow.show()

		if item.stats.rarity in [GlobalData.ItemRarity.EPIC, GlobalData.ItemRarity.LEGENDARY, GlobalData.ItemRarity.SINGULAR]:
			var gradient_texture: GradientTexture1D = GradientTexture1D.new()
			gradient_texture.gradient = Gradient.new()
			gradient_texture.gradient.add_point(0, GlobalData.rarity_colors.glint_color.get(item.stats.rarity))
			item_texture.material.set_shader_parameter("color_gradient", gradient_texture)
			item_texture.material.set_shader_parameter("highlight_strength", 0.4)
		else:
			item_texture.material.set_shader_parameter("highlight_strength", 0.0)

		if item.quantity > 1:
			quantity.text = str(item.quantity)
		else:
			quantity.text = ""
	else:
		update_tint_progress(0)
		item = null
		item_texture.texture = null
		quantity.text = ""
		rarity_glow.hide()
		back_color.hide()
		texture_margins.rotation = 0
		texture_margins.position = Vector2.ZERO
		texture_margins.scale = Vector2.ONE

	item_changed.emit(self, old_item, item)

## Connects relevant mouse entered and exited functions.
func _ready() -> void:
	mouse_entered.connect(func() -> void: is_hovered_over.emit(index))
	mouse_exited.connect(func() -> void: is_not_hovered_over.emit())
	backing_texture_rect.texture = backing_texture
	rarity_glow.hide()
	selected_texture.hide()
	item_texture.material.set_shader_parameter("highlight_strength", 0.0)
	texture_margins.pivot_offset = texture_margins.size / 2

## When this is shown or hidden and different slots are displayed, update the local tint progress
## with the current item.
func _on_visibility_changed() -> void:
	await get_tree().process_frame
	update_tint_progress(GlobalData.player_node.inv.auto_decrementer.get_cooldown(item.stats.get_cooldown_id()) if item != null else 0.0)

## Updates the upwards fill tinting that represents an item on cooldown.
func update_tint_progress(duration: float) -> void:
	if duration > 0:
		var cooldown_source: String = GlobalData.player_node.inv.auto_decrementer.get_cooldown_source_title(item.stats.get_cooldown_id())
		if cooldown_source not in item.stats.shown_cooldown_fills:
			return

		if tint_tween: tint_tween.kill()
		tint_progress = (1 - (duration / GlobalData.player_node.inv.auto_decrementer.get_original_cooldown(item.stats.get_cooldown_id()))) * 100
		if not GlobalData.focused_ui_is_open:
			tint_tween = create_tween()
			tint_tween.tween_property(self, "tint_progress", 100.0, duration)
	else:
		tint_progress = 100.0

## Gets a reference to the data from the slot where the drag originated.
func _get_drag_data(at_position: Vector2) -> Variant:
	dragging_half_stack = false
	dragging_only_one = false
	if item != null and not is_hud_ui_preview_slot:
		modulate = Color(0.65, 0.65, 0.65, 1)
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
		preview_tex_margins.position = item.stats.inv_icon_offset
		preview_tex_margins.scale = item.stats.inv_icon_scale

		var outline_width: float = (0.5 * (max(item_texture.texture.get_width() / item.stats.inv_icon_scale.x, item_texture.texture.get_height() / item.stats.inv_icon_scale.y) / item_texture.custom_minimum_size.x))

		preview_texture.material.set_shader_parameter("width", outline_width)
		preview_texture.material.set_shader_parameter("highlight_strength", 0.0)
		preview_texture.material.set_shader_parameter("outline_color", GlobalData.rarity_colors.outline_color.get(item.stats.rarity))

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
				if Input.is_action_pressed("sprint") and item.quantity > 1:
					dragging_half_stack = true
					quantity.text = str(item.quantity - int(floor(item.quantity / 2.0)))
				else:
					if item.quantity - 1 > 0:
						dragging_only_one = true
						quantity.text = str(item.quantity - 1)
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
	if data.item == null or not synced_inv or data.index == index or is_hud_ui_preview_slot:
		return false
	if data is ModSlot:
		if item != null and not (item.stats.is_same_as(data.item.stats) and item.quantity < item.stats.stack_size):
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

	is_hovered_over.emit(index)
	_on_mouse_exited()

#region Dropping Full Stacks
## Moves all items from drag into a different empty slot.
func _move_items_to_other_empty_slot(data: Variant) -> void:
	item = InvItemResource.new(data.item.stats, data.item.quantity)
	if index < synced_inv.inv.size():
		synced_inv.inv[index] = item

	if data.index < synced_inv.inv.size():
		synced_inv.inv[data.index] = null
	data.item = null

	_emit_changes_for_potential_listening_hotbar(data)

## Combines the drag data items into a slot with items of the same kind. This means that when
## combined they still fit stack size.
func _combine_all_items_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	_set_item(item)

	if data.index < synced_inv.inv.size():
		synced_inv.inv[data.index] = null
	data.item = null

	_emit_changes_for_potential_listening_hotbar(data)

## Combines items of same kind from drag data into an already occupied slot. Passes what doesn't
## fit to the next iteration.
func _combine_what_fits_and_leave_remainder(data: Variant) -> void:
	var amount_that_fits: int = item.stats.stack_size - item.quantity
	item.quantity = item.stats.stack_size
	_set_item(item)

	if is_trash_slot:
		if not data.dragging_half_stack:
			if data.index < synced_inv.inv.size():
				synced_inv.inv[data.index] = null
			data.item = null
		else:
			data.item = InvItemResource.new(data.item.stats, data.item.quantity - int(floor(data.item.quantity / 2.0)))
			if data.index < synced_inv.inv.size():
				synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, data.item.quantity)
	else:
		data.item = InvItemResource.new(data.item.stats, data.item.quantity - amount_that_fits)
		if data.index < synced_inv.inv.size():
			synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, data.item.quantity)
			data.item = synced_inv.inv[data.index]

	_emit_changes_for_potential_listening_hotbar(data)

## Swaps slot data's.
func _swap_item_stacks(data: Variant) -> void:
	var temp_item: InvItemResource = item
	item = InvItemResource.new(data.item.stats, data.item.quantity)
	if index < synced_inv.inv.size():
		synced_inv.inv[index] = item

	if is_trash_slot:
		if data.index < synced_inv.inv.size():
			synced_inv.inv[data.index] = null
		data.item = null
	else:
		if data.index < synced_inv.inv.size():
			synced_inv.inv[data.index] = temp_item
		data.item = temp_item

	_emit_changes_for_potential_listening_hotbar(data)
#endregion

#region Dropping Only One
## Moves a quantity of 1 from an item slot to an empty slot.
func _move_one_item_to_empty_slot(data: Variant) -> void:
	item = InvItemResource.new(data.item.stats, 1)
	if index < synced_inv.inv.size():
		synced_inv.inv[index] = item
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

## Moves a quantity of 1 from the drag data into a slot of the same kind with space.
func _add_one_item_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	_set_item(item)
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

func _replace_with_one_item_and_find_available_slot_for_previous_stuff(data: Variant) -> void:
	var temp_item: InvItemResource = item
	item = InvItemResource.new(data.item.stats, 1)
	if index < synced_inv.inv.size():
		synced_inv.inv[index] = item

	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

	if not is_trash_slot:
		synced_inv.add_item_from_inv_item_resource(temp_item, false)

	_emit_changes_for_potential_listening_hotbar(data)

## After moving a quantity of 1 in any way, checks that the source did not only have 1 to
## begin with and would then need to be cleared out.
func _check_if_inv_slot_is_now_empty_after_dragging_only_one(data: Variant) -> void:
	if data.index < synced_inv.inv.size():
		if synced_inv.inv[data.index].quantity - 1 <= 0:
			synced_inv.inv[data.index] = null
		else:
			synced_inv.inv[data.index].quantity -= 1

		data.item = synced_inv.inv[data.index]
	else:
		if data.item.quantity - 1 <= 0:
			data.item = null
		else:
			data.item = InvItemResource.new(data.item.stats, data.item.quantity - 1)

	_emit_changes_for_potential_listening_hotbar(data)
#endregion

#region Dropping Half Stacks
## Moves all of the half quantity represented by the drag data into a slot with space, empty or not.
func _move_all_of_the_half_stack_into_a_slot(data: Variant, source_remainder: int, total_quantity: int) -> void:
	item = InvItemResource.new(data.item.stats, total_quantity)
	if index < synced_inv.inv.size():
		synced_inv.inv[index] = item

	if data.index < synced_inv.inv.size():
		synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, source_remainder)
		data.item = synced_inv.inv[data.index]
	else:
		data.item = InvItemResource.new(data.item.stats, source_remainder)

	_emit_changes_for_potential_listening_hotbar(data)

## Moves what fits from the half quantity represented by the drag data into a slot that can take some of it.
## Leaves what doesn't fit.
func _move_part_of_half_stack_into_slot_and_leave_remainder(data: Variant) -> void:
	_combine_what_fits_and_leave_remainder(data)

func _replace_with_half_stack_and_find_available_slot_for_previous_stuff(data: Variant, source_remainder: int,
																			total_quantity: int) -> void:
	var temp_item: InvItemResource = item
	item = InvItemResource.new(data.item.stats, total_quantity)
	if index < synced_inv.inv.size():
		synced_inv.inv[index] = item

	if not is_trash_slot:
		synced_inv.add_item_from_inv_item_resource(temp_item, false)

	if data.index < synced_inv.inv.size():
		synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, source_remainder)
		data.item = synced_inv.inv[data.index]
	else:
		data.item = InvItemResource.new(data.item.stats, source_remainder)

	_emit_changes_for_potential_listening_hotbar(data)
#endregion

#region Utils
## Emits signals for all slots of high enough index when changed to let any connected hotbar
## know to change it's data and UI.
func _emit_changes_for_potential_listening_hotbar(data: Variant) -> void:
	if data.index >= (synced_inv.inv_size - synced_inv.hotbar_size) and (data.index < synced_inv.inv.size()):
		synced_inv.slot_updated.emit(data.index, data.item)
	if index >= (synced_inv.inv_size - synced_inv.hotbar_size) and (index < synced_inv.inv.size()):
		synced_inv.slot_updated.emit(index, item)

## When mouse enters, if we can drop, display an effect on this slot.
func _on_mouse_entered() -> void:
	Slot.hovered_slot_size = size.x
	if get_viewport().gui_is_dragging():
		var drag_data: Variant = get_viewport().gui_get_drag_data()
		if _can_drop_data(get_local_mouse_position(), drag_data):
			modulate = Color(1.2, 1.2, 1.2, 1.0)
			if item == null:
				item_texture.texture = drag_data.item_texture.texture
				texture_margins.rotation_degrees = drag_data.item.stats.inv_icon_rotation
				texture_margins.position = drag_data.item.stats.inv_icon_offset * (item_texture.size / item_texture.custom_minimum_size)
				texture_margins.scale = drag_data.item.stats.inv_icon_scale
				item_texture.modulate.a = 0.5

				item_texture.material.set_shader_parameter("width", 0)

## When mouse exits, if we are dragging, remove effects on this slot.
func _on_mouse_exited() -> void:
	var drag_data: Variant
	if get_viewport().gui_is_dragging():
		drag_data = get_viewport().gui_get_drag_data()
		if drag_data.index == index:
			return
	modulate = Color(1, 1, 1, 1)
	if item == null and drag_data:
		item_texture.texture = null
		texture_margins.rotation = 0
		texture_margins.position = Vector2.ZERO
		texture_margins.scale = Vector2.ONE
		item_texture.modulate.a = 1.0

## When the system is notifed of a drag being over, call the method that resets slot highlight and
## drag preview effects.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_reset_post_drag_mods()

## Resets slot highlights and drag preview effects.
func _reset_post_drag_mods() -> void:
	dragging_only_one = false
	dragging_half_stack = false
	modulate = Color(1, 1, 1, 1)
	if item == null:
		item_texture.texture = null
		texture_margins.rotation = 0
		texture_margins.position = Vector2.ZERO
		texture_margins.scale = Vector2.ONE
	elif item.quantity > 1:
		quantity.text = str(item.quantity)
	item_texture.modulate.a = 1.0

## Custom string representation of the item in this slot.
func _to_string() -> String:
	return str(item)

## When an item is double clicked in the inventory, attempt to garner a full stack by iterating
## over all other slots.
## Pulls from slots not at stack size first, then goes back and gets from stack size if needed.
func _fill_slot_to_stack_size() -> void:
	var needed_quantity: int = item.stats.stack_size - item.quantity
	if needed_quantity <= 0:
		return

	# First pass: Pull from non-full slots
	for i: int in range(synced_inv.inv.size()):
		if i == index:
			continue

		var other_item: InvItemResource = synced_inv.inv[i]
		if other_item != null and other_item.stats.is_same_as(item.stats) and other_item.quantity < other_item.stats.stack_size:
			var transfer_quantity: int = min(needed_quantity, other_item.quantity)
			item.quantity += transfer_quantity
			other_item.quantity -= transfer_quantity
			needed_quantity -= transfer_quantity

		if other_item:
			synced_inv.inv[i] = other_item

		synced_inv.slot_updated.emit(i, synced_inv.inv[i])

		if needed_quantity <= 0:
			break

	# Second pass: Pull from full slots if needed
	if needed_quantity > 0:
		for i: int in range(synced_inv.inv.size()):
			if i == index:
				continue

			var other_item: InvItemResource = synced_inv.inv[i]
			if other_item != null and other_item.stats.is_same_as(item.stats):
				var transfer_quantity: int = min(needed_quantity, other_item.quantity)
				item.quantity += transfer_quantity
				other_item.quantity -= transfer_quantity
				needed_quantity -= transfer_quantity

				if other_item:
					synced_inv.inv[i] = other_item

				synced_inv.slot_updated.emit(i, synced_inv.inv[i])

				if needed_quantity <= 0:
					break

	_set_item(item)
	synced_inv.slot_updated.emit(index, item)
#endregion
