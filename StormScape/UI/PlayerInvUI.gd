extends ColorRect
class_name PlayerInvUI

@onready var slot_grid: InventoryPopulator = $TextureMargins/InventoryTexture/GridMargins/SlotGrid


func _ready() -> void:
	visible = false

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("player_inventory"):
		visible = !visible
		get_tree().paused = !get_tree().paused
