extends ColorRect
class_name InventoryUI

@export var item_scene: PackedScene = load("res://Entities/Items/Item.tscn")

var inventory_to_reflect: Inventory


func _ready() -> void:
	visible = false
	gui_input.connect(_on_blank_space_input_event)

func connect_inventory(inv: Inventory) -> void:
	inventory_to_reflect = inv

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data and ("item" in data) and (data.item != null):
		return true
	else: return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var ground_item_res: ItemResource = data.item.stats.duplicate()
	if ground_item_res and data:
		var ground_item: Item = item_scene.instantiate()
		ground_item.stats = ground_item_res
		if data.dragging_only_one:
			ground_item.quantity = 1
			if inventory_to_reflect.inv[data.index].quantity - 1 <= 0:
				inventory_to_reflect.inv[data.index] = null
			else:
				inventory_to_reflect.inv[data.index].quantity -= 1

			data.item = inventory_to_reflect.inv[data.index]
		elif data.dragging_half_stack:
			var half_quantity: int = int(floor(data.item.quantity / 2.0))
			var remainder: int = data.item.quantity - half_quantity
			ground_item.quantity = half_quantity

			inventory_to_reflect.inv[data.index].quantity = remainder
			data.item = inventory_to_reflect.inv[data.index]
		else:
			ground_item.quantity = data.item.quantity
			data.item = null
			inventory_to_reflect.inv[data.index] = null

		ground_item.global_position = GlobalData.player_node.global_position + Vector2(randi_range(-17, 12) + 6, randi_range(-17, 12) + 6)
		GlobalData.world_root.get_node("Testing").add_child(ground_item)

	var inv_to_reflect_main_size: int = inventory_to_reflect.inv_size - inventory_to_reflect.hotbar_size
	if data.index >= inv_to_reflect_main_size: inventory_to_reflect.slot_updated.emit(data.index, data.item)

	data._on_mouse_exited()

func _on_blank_space_input_event(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("primary"):
		visible = false
		get_tree().paused = false
