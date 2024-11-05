extends InventoryUI
class_name PlayerInvUI


func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("player_inventory"):
		visible = !visible
		get_tree().paused = !get_tree().paused

		if get_viewport().gui_is_dragging():
			var drag_end_event = InputEventMouseButton.new()
			drag_end_event.button_index = MOUSE_BUTTON_LEFT
			drag_end_event.position = position
			drag_end_event.pressed = false
			Input.parse_input_event(drag_end_event)
	elif Input.is_action_just_pressed("esc"):
		visible = false
		get_tree().paused = false


func _on_sort_by_name_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_name()

func _on_sort_by_rarity_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_rarity()

func _on_sort_by_count_btn_pressed() -> void:
	GlobalData.player_node.get_node("ItemReceiverComponent").activate_sort_by_count()
