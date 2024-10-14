extends Control
class_name ItemSlot


@onready var texture: TextureRect = %Texture

var stats: Item = null: set = _set_item


func _set_item(item_stats: Item) -> void:
	stats = item_stats
	
	if stats:
		texture.texture = stats.icon
