@tool
extends Area2D
class_name Item
## Base class for all items in the game. Defines logic for interacting with entities that can pick it up.

@export var stats: ItemResource = null: set = _set_item ## The item resource driving the stats and type of item.
@export var quantity: int = 1 ## The quantity associated with the physical item.

@onready var thumbnail: Sprite2D = $Sprite2D ## The sprite that shows the item's texture.
@onready var shadow: Sprite2D = $ShadowScaler/Shadow


func _ready() -> void:
	_set_item(stats)

func _on_area_entered(area: Area2D) -> void:
	if area is ItemReceiverComponent:
		(area as ItemReceiverComponent).add_to_in_range_queue(self)

func _on_area_exited(area: Area2D) -> void:
	if area is ItemReceiverComponent:
		(area as ItemReceiverComponent).remove_from_in_range_queue(self)

func _set_item(item_stats: ItemResource) -> void:
	stats = item_stats
	if stats and thumbnail:
		thumbnail.texture = stats.thumbnail
		if shadow:
			shadow.scale.x = thumbnail.texture.get_width() / 16.0
			shadow.scale.y = thumbnail.texture.get_height() / 32.0
			shadow.position.y = ceil(thumbnail.texture.get_height() / 2.0) + ceil(shadow.texture.get_height() / 2.0) - 2
