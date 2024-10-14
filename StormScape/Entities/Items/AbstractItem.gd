extends Node2D
class_name AbstractItem


@onready var sprite: Sprite2D = $Sprite2D

var stats: Item = null: set = _set_item

func _set_item(item_stats: Item) -> void:
	stats = item_stats
	if stats:
		sprite.texture = stats.icon
