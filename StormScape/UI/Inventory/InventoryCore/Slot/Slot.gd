@tool
extends NinePatchRect
class_name Slot
## The item and quantity representation inside all inventories. Handles drag and drop logic as well as stacking.

signal is_hovered_over(index: int) ## Emitted when a slot is currently being hovered over.
signal is_not_hovered_over() ## Emitted when a slot is no longer being hovered over.

@export var drag_preview: PackedScene = load("res://UI/Inventory/InventoryCore/Slot/SlotDragPreview.tscn") ## The control preview for a dragged slot.
@export var default_slot_texture: Texture2D = load("res://UI/Inventory/InventoryCore/Slot/inv_slot_9_patch.png")
@export var active_slot_texture: Texture2D = load("res://UI/Inventory/InventoryCore/Slot/inv_slot_active_9_patch.png")

@onready var item_texture: TextureRect = $TextureMargins/ItemTexture ## The item texture node for this slot.
@onready var quantity: Label = $QuantityMargins/Quantity ## The quantity label for this slot.

var index: int ## The index that this slot represents inside the inventory.
var synced_inv: Inventory ## The synced inventory that this slot is a part of.
var dragging_only_one: bool = false ## Whether this slot is carrying only a quantity of 1 when in drag data.
var dragging_half_stack: bool = false ## Whether this slot is carrying only half of its quantity when in drag data.
var item: InvItemResource: set = _set_item ## The current inventory item represented in this slot.
var is_hotbar_ui_preview_slot: bool = false ## Whether this slot is an inventory hotbar preview slot for the player's screen.
var is_trash_slot: bool = false ## The slot, that if present, is used to discard items. It will have the highest index.


## Setter function for the item represented by this slot. Updates texture and quantity label.
func _set_item(new_item) -> void:
	item = new_item
	if item:
		item_texture.texture = item.stats.icon
		if item.quantity > 0:
			if item.quantity > 1:
				quantity.text = str(item.quantity)
			else:
				quantity.text = ""
		else:
			item = null
			item_texture.texture = null
			quantity.text = ""
			return
	else:
		item_texture.texture = null
		quantity.text = ""

## Connects relevant mouse entered and exited functions.
func _ready() -> void:
	mouse_entered.connect(func(): is_hovered_over.emit(index))
	mouse_exited.connect(func(): is_not_hovered_over.emit())

## Gets a reference to the data from the slot where the drag originated.
func _get_drag_data(at_position: Vector2) -> Variant:
	dragging_half_stack = false
	dragging_only_one = false
	if item != null and not is_hotbar_ui_preview_slot:
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
	if item and item.stats.icon and item.quantity > 0:
		var preview_scene: Control = drag_preview.instantiate()
		preview_scene.get_node("TextureMargins/ItemTexture").texture = item.stats.icon
		if dragging_only_one:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(1)
		elif dragging_half_stack:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(int(floor(item.quantity / 2.0)))
		else:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(item.quantity)
		preview_scene.modulate.a = 0.65
		preview_scene.position = -at_position
		c.add_child(preview_scene)
	return c

#region RightClick Drags
## When a right click drag is released, interpret it as a left click drag. Allows right drags to work with Godot's drag system.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			if get_viewport().gui_is_dragging():
				event = event.duplicate()
				event.button_index = MOUSE_BUTTON_LEFT
				Input.parse_input_event(event)

## When we start a right click drag, interpret it as starting a left click drag. Runs single quantity and half quantity logic.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if item != null:
				if Input.is_action_pressed("sprint") and item.quantity > 1:
					dragging_half_stack = true
					quantity.text = str(item.quantity - int(floor(item.quantity / 2.0)))
				else:
					dragging_only_one = true
					if item.quantity - 1 > 0:
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
	if data.item == null or not synced_inv or data.index == index or is_hotbar_ui_preview_slot:
		return false
	if item == null or is_trash_slot:
		return true
	if item.stats.is_same_as(data.item.stats):
		if item.quantity >= item.stats.stack_size:
			return false
		else:
			return true
	else:
		if data.dragging_only_one or data.dragging_half_stack:
			return false
	return true

## Drops item slot drag data into the hovered slot, updating the current and source slot based on quantities and drag method.
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

	is_hovered_over.emit(index)
	_on_mouse_exited()

#region Dropping Full Stacks
## Moves all items from drag into a different empty slot.
func _move_items_to_other_empty_slot(data: Variant) -> void:
	item = InvItemResource.new(data.item.stats, data.item.quantity)
	synced_inv.inv[index] = item

	synced_inv.inv[data.index] = null
	data.item = null

	_emit_changes_for_potential_listening_hotbar(data)

## Combines the drag data items into a slot with items of the same kind. This means that when combined they still fit stack size.
func _combine_all_items_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	_set_item(item)

	synced_inv.inv[data.index] = null
	data.item = null

	_emit_changes_for_potential_listening_hotbar(data)

## Combines items of same kind from drag data into an already occupied slot. Passes what doesn't fit to the next iteration.
func _combine_what_fits_and_leave_remainder(data: Variant) -> void:
	var amount_that_fits: int = item.stats.stack_size - item.quantity
	item.quantity = item.stats.stack_size
	_set_item(item)

	if is_trash_slot:
		if not data.dragging_half_stack:
			synced_inv.inv[data.index] = null
			data.item = null
		else:
			data.item.quantity -= int(floor(data.item.quantity / 2.0))
			synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, data.item.quantity)
	else:
		data.item.quantity -= amount_that_fits
		synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, data.item.quantity)
		data.item = synced_inv.inv[data.index]

	_emit_changes_for_potential_listening_hotbar(data)

## Swaps slot data's.
func _swap_item_stacks(data: Variant) -> void:
	var temp_item = item
	item = InvItemResource.new(data.item.stats, data.item.quantity)
	synced_inv.inv[index] = item

	if is_trash_slot:
		synced_inv.inv[data.index] = null
		data.item = null
	else:
		synced_inv.inv[data.index] = temp_item
		data.item = temp_item

	_emit_changes_for_potential_listening_hotbar(data)
#endregion

#region Dropping Only One
## Moves a quantity of 1 from an item slot to an empty slot.
func _move_one_item_to_empty_slot(data: Variant) -> void:
	item = InvItemResource.new(data.item.stats, 1)
	synced_inv.inv[index] = item
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

## Moves a quantity of 1 from the drag data into a slot of the same kind with space.
func _add_one_item_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	_set_item(item)
	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

## After moving a quantity of 1 in any way, checks that the source did not only have 1 to begin with and would then need to be ## cleared out.
func _check_if_inv_slot_is_now_empty_after_dragging_only_one(data: Variant) -> void:
	if synced_inv.inv[data.index].quantity - 1 <= 0:
		synced_inv.inv[data.index] = null
	else:
		synced_inv.inv[data.index].quantity -= 1

	data.item = synced_inv.inv[data.index]

	_emit_changes_for_potential_listening_hotbar(data)
#endregion

#region Dropping Half Stacks
## Moves all of the half quantity represented by the drag data into a slot with space, empty or not.
func _move_all_of_the_half_stack_into_a_slot(data: Variant, source_remainder: int, total_quantity: int) -> void:
	item = InvItemResource.new(data.item.stats, total_quantity)
	synced_inv.inv[index] = item

	synced_inv.inv[data.index] = InvItemResource.new(data.item.stats, source_remainder)
	data.item = synced_inv.inv[data.index]

	_emit_changes_for_potential_listening_hotbar(data)

## Moves what fits from the half quantity represented by the drag data into a slot that can take some of it.
## Leaves what doesn't fit.
func _move_part_of_half_stack_into_slot_and_leave_remainder(data: Variant) -> void:
	_combine_what_fits_and_leave_remainder(data)
#endregion

#region Utils
## Emits signals for all slots of high enough index when changed to let any connected hotbar know to change it's data and UI.
func _emit_changes_for_potential_listening_hotbar(data: Variant) -> void:
	if data.index >= synced_inv.inv_size - synced_inv.hotbar_size: synced_inv.slot_updated.emit(data.index, data.item)
	if index >= synced_inv.inv_size - synced_inv.hotbar_size: synced_inv.slot_updated.emit(index, item)

## When mouse enters, if we can drop, display an effect on this slot.
func _on_mouse_entered() -> void:
	if get_viewport().gui_is_dragging():
		var drag_data = get_viewport().gui_get_drag_data()
		if _can_drop_data(get_local_mouse_position(), drag_data):
			modulate = Color(1.2, 1.2, 1.2, 1.0)
			if item == null:
				item_texture.texture = drag_data.item_texture.texture
				item_texture.modulate.a = 0.5

## When mouse exits, if we are dragging, remove effects on this slot.
func _on_mouse_exited() -> void:
	var drag_data
	if get_viewport().gui_is_dragging():
		drag_data = get_viewport().gui_get_drag_data()
		if drag_data.index == index:
			return
	modulate = Color(1, 1, 1, 1)
	if item == null and drag_data:
		item_texture.texture = null
		item_texture.modulate.a = 1.0

## When the system is notifed of a drag being over, call the method that resets slot highlight and drag preview effects.
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		_reset_post_drag_mods()

## Resets slot highlights and drag preview effects.
func _reset_post_drag_mods() -> void:
	dragging_only_one = false
	dragging_half_stack = false
	modulate = Color(1, 1, 1, 1)
	if item == null:
		item_texture.texture = null
	elif item.quantity > 1:
		quantity.text = str(item.quantity)
	item_texture.modulate.a = 1.0

## Custom string representation of the item in this slot.
func _to_string() -> String:
	return str(item)

## When an item is double clicked in the inventory, attempt to garner a full stack by iterating over all other slots.
## Pulls from slots not at stack size first, then goes back and gets from stack size if needed.
func _fill_slot_to_stack_size() -> void:
	var needed_quantity = item.stats.stack_size - item.quantity
	if needed_quantity <= 0:
		return

	# First pass: Pull from non-full slots
	for i in range(synced_inv.inv.size()):
		if i == index:
			continue

		var other_item = synced_inv.inv[i]
		if other_item != null and other_item.stats.is_same_as(item.stats) and other_item.quantity < other_item.stats.stack_size:
			var transfer_quantity = min(needed_quantity, other_item.quantity)
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
		for i in range(synced_inv.inv.size()):
			if i == index:
				continue

			var other_item = synced_inv.inv[i]
			if other_item != null and other_item.stats.is_same_as(item.stats):
				var transfer_quantity = min(needed_quantity, other_item.quantity)
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
