extends ColorRect
class_name InventoryUI
## The base class for all inventory UIs. Handles drag and dropping into margin space for dropping onto the ground.

@export var item_scene: PackedScene = preload("res://Entities/Items/ItemCore/Item.tscn") ## The item scene to be instantiated when items are dropped onto the ground.

var inventory_to_reflect: Inventory ## The inventory to reflect in this UI.


func _ready() -> void:
	visible = false
	gui_input.connect(_on_blank_space_input_event)

## Called externally to connect an inventory to this UI.
func connect_inventory(inv: Inventory) -> void:
	inventory_to_reflect = inv

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
			if data.index < inventory_to_reflect.inv.size():
				if inventory_to_reflect.inv[data.index].quantity - 1 <= 0:
					inventory_to_reflect.inv[data.index] = null
				else:
					inventory_to_reflect.inv[data.index].quantity -= 1

				data.item = inventory_to_reflect.inv[data.index]
			else:
				if data.item.quantity - 1 <= 0:
					data.item = null
				else:
					data.item.quantity -= 1
		elif data.dragging_half_stack:
			var half_quantity: int = int(floor(data.item.quantity / 2.0))
			var remainder: int = data.item.quantity - half_quantity
			ground_item_quantity = half_quantity

			if data.index < inventory_to_reflect.inv.size():
				inventory_to_reflect.inv[data.index].quantity = remainder
				data.item = inventory_to_reflect.inv[data.index]
			else:
				data.item.quantity = remainder
		else:
			ground_item_quantity = data.item.quantity
			data.item = null
			if data.index < inventory_to_reflect.inv.size():
				inventory_to_reflect.inv[data.index] = null

		Item.spawn_on_ground(ground_item_res, ground_item_quantity, Globals.player_node.global_position, 15, true)

	if data.index < inventory_to_reflect.inv.size():
		inventory_to_reflect.slot_updated.emit(data.index, data.item)

	data._on_mouse_exited()

## When the empty space of the inventory screen is clicked, we close the inventory altogether.
func _on_blank_space_input_event(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("primary"):
		visible = false
		get_tree().paused = false
