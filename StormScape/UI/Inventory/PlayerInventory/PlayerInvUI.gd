extends InventoryUI
class_name PlayerInvUI

@export var hotbar_ui: NinePatchRect ## The hotbar UI to control visibility for.


## Checks when we open and close the player inventory based on certain key inputs.
func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("player_inventory"):
		visible = !visible
		get_tree().paused = !get_tree().paused
		hotbar_ui.visible = !hotbar_ui.visible
	elif Input.is_action_just_pressed("esc"):
		visible = false
		get_tree().paused = false
		hotbar_ui.visible = true

	# If we are dragging when we press any key, end the drag.
	if get_viewport().gui_is_dragging():
		var drag_end_event = InputEventMouseButton.new()
		drag_end_event.button_index = MOUSE_BUTTON_LEFT
		drag_end_event.position = position
		drag_end_event.pressed = false
		Input.parse_input_event(drag_end_event)

## When we click the empty space around this player inventory, change needed visibilities.
func _on_blank_space_input_event(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("primary"):
		visible = false
		get_tree().paused = false
		hotbar_ui.visible = true

## Activates sorting this inventory by name.
func _on_sort_by_name_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_name()

## Activates sorting this inventory by rarity.
func _on_sort_by_rarity_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_rarity()

## Activates sorting this inventory by count.
func _on_sort_by_count_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_count()

## Activates auto-stacking this inventory.
func _on_auto_stack_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_auto_stack()
