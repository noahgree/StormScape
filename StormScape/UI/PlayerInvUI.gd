extends InventoryUI
class_name PlayerInvUI


func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("player_inventory"):
		visible = !visible
		get_tree().paused = !get_tree().paused
	elif Input.is_action_just_pressed("esc"):
		visible = false
		get_tree().paused = false
