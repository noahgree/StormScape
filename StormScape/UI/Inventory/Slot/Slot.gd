@tool
extends NinePatchRect
class_name Slot

signal is_hovered_over(index: int)
signal is_not_hovered_over()

@export var drag_preview: PackedScene

@onready var item_texture: TextureRect = $TextureMargins/ItemTexture
@onready var quantity: Label = $QuantityMargins/Quantity

var index: int
var synced_inv: Inventory:
	set(new_synced_inv):
		synced_inv = new_synced_inv
		synced_inv_main_size = synced_inv.inv_size - synced_inv.hotbar_size
var dragging_only_one: bool = false
var item: InventoryItem: set = _set_item
var synced_inv_main_size: int
var is_hotbar_ui_preview_slot: bool = false


func _set_item(new_item) -> void:
	item = new_item
	if item:
		item_texture.texture = item.stats.icon
		if item.quantity > 0:
			quantity.text = str(item.quantity)
		else:
			item = null
			item_texture.texture = null
			quantity.text = ""
			return
	else:
		item_texture.texture = null
		quantity.text = ""

func _ready() -> void:
	mouse_entered.connect(func(): is_hovered_over.emit(index))
	mouse_exited.connect(func(): is_not_hovered_over.emit())

func _to_string() -> String:
	return str(item)

func _get_drag_data(at_position: Vector2) -> Variant:
	dragging_only_one = false

	if item != null and not is_hotbar_ui_preview_slot:
		set_drag_preview(_make_drag_preview(at_position))
		return self
	else:
		return null

func _make_drag_preview(at_position: Vector2) -> Control:
	var c: Control = Control.new()
	if item and item.stats.icon and item.quantity > 0:
		var preview_scene: Control = drag_preview.instantiate()
		preview_scene.get_node("TextureMargins/ItemTexture").texture = item.stats.icon
		if not dragging_only_one:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(item.quantity)
		else:
			preview_scene.get_node("QuantityMargins/Quantity").text = str(1)
		preview_scene.modulate.a = 0.65
		preview_scene.position = -at_position
		c.add_child(preview_scene)
	return c

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			if get_viewport().gui_is_dragging():
				event = event.duplicate()
				event.button_index = MOUSE_BUTTON_LEFT
				Input.parse_input_event(event)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if item != null:
				dragging_only_one = true
				force_drag(self, _make_drag_preview(get_local_mouse_position()))

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data.item == null or not synced_inv or data.index == index or is_hotbar_ui_preview_slot:
		return false
	if item == null:
		return true
	if item.quantity >= item.stats.stack_size:
		return false
	return item.stats.is_same_as(data.item.stats)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data and synced_inv):
		return

	if item == null:
		if data.dragging_only_one:
			_move_only_one_to_empty_slot(data)
		else:
			_move_items_to_other_empty_slot(data)
	else:
		if item.stats.is_same_as(data.item.stats):
			if data.dragging_only_one:
				var total_quantity: int = item.quantity + 1
				if total_quantity <= item.stats.stack_size:
					_add_one_item_into_slot_with_space(data, total_quantity)
			else:
				var total_quantity: int = item.quantity + data.item.quantity
				if total_quantity <= item.stats.stack_size:
					_combine_all_items_into_slot_with_space(data, total_quantity)
				else:
					_combine_what_fits_and_leave_remainder(data)

	is_hovered_over.emit(index)

func _move_items_to_other_empty_slot(data: Variant) -> void:
	item = InventoryItem.new(data.item.stats, data.item.quantity)
	synced_inv.inv[index] = item

	synced_inv.inv[data.index] = null
	data.item = null

	_emit_changes_for_potential_listening_hotbar(data)

func _combine_all_items_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	_set_item(item)

	synced_inv.inv[data.index] = null
	data.item = null

	_emit_changes_for_potential_listening_hotbar(data)

func _combine_what_fits_and_leave_remainder(data: Variant) -> void:
	var amount_that_fits: int = item.stats.stack_size - item.quantity
	item.quantity = item.stats.stack_size
	_set_item(item)

	data.item.quantity -= amount_that_fits
	synced_inv.inv[data.index] = InventoryItem.new(data.item.stats, data.item.quantity)
	data.item = synced_inv.inv[data.index]

	_emit_changes_for_potential_listening_hotbar(data)

func _move_only_one_to_empty_slot(data: Variant) -> void:
	item = InventoryItem.new(data.item.stats, 1)
	synced_inv.inv[index] = item

	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

func _add_one_item_into_slot_with_space(data: Variant, total_quantity: int) -> void:
	item.quantity = total_quantity
	_set_item(item)

	_check_if_inv_slot_is_now_empty_after_dragging_only_one(data)

func _check_if_inv_slot_is_now_empty_after_dragging_only_one(data: Variant) -> void:
	if synced_inv.inv[data.index].quantity - 1 <= 0:
		synced_inv.inv[data.index] = null
	else:
		synced_inv.inv[data.index].quantity -= 1

	data.item = synced_inv.inv[data.index]

	_emit_changes_for_potential_listening_hotbar(data)

func _emit_changes_for_potential_listening_hotbar(data: Variant) -> void:
	if data.index >= synced_inv_main_size: synced_inv.slot_updated.emit(data.index, data.item)
	if index >= synced_inv_main_size: synced_inv.slot_updated.emit(index, item)
