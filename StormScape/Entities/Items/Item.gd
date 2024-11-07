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
	if not Engine.is_editor_hint():
		thumbnail.material.set_shader_parameter("random_start_offset", randf() * 2.0)

func _on_area_entered(area: Area2D) -> void:
	if area is ItemReceiverComponent and area.get_parent() is Player:
		(area as ItemReceiverComponent).add_to_in_range_queue(self)

		for item in (area as ItemReceiverComponent).items_in_range:
			item.thumbnail.material.set_shader_parameter("width", 0)
		(area as ItemReceiverComponent).items_in_range[area.items_in_range.size() - 1].thumbnail.material.set_shader_parameter("width", 0.75)

func _on_area_exited(area: Area2D) -> void:
	if area is ItemReceiverComponent and area.get_parent() is Player:
		(area as ItemReceiverComponent).remove_from_in_range_queue(self)

		thumbnail.material.set_shader_parameter("width", 0)
		if not (area as ItemReceiverComponent).items_in_range.is_empty():
			(area as ItemReceiverComponent).items_in_range[area.items_in_range.size() - 1].thumbnail.material.set_shader_parameter("width", 0.75)


func _set_item(item_stats: ItemResource) -> void:
	stats = item_stats
	if stats and thumbnail:
		thumbnail.texture = stats.thumbnail
		if shadow:
			shadow.scale.x = thumbnail.texture.get_width() / 16.0
			shadow.scale.y = thumbnail.texture.get_height() / 32.0
			shadow.position.y = ceil(thumbnail.texture.get_height() / 2.0) + ceil(shadow.texture.get_height() / 2.0) - 2
