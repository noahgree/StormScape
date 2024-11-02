@tool
extends Area2D
class_name Item
## Base class for all items in the game. Defines logic for interacting with entities that can pick it up.

@export var stats: ItemResource = null: set = _set_item ## The item resource driving the stats and type of item.
@export var quantity: int = 1 ## The quantity associated with the physical item.

@onready var icon: Sprite2D = $Sprite2D ## The sprite that shows the item's texture.


func _ready() -> void:
	_set_item(stats)

func _on_area_entered(area: Area2D) -> void:
	var inv: ItemReceiverComponent = area.get_node_or_null("ItemReceiverComponent")
	if inv: inv.add_to_in_range_queue(self)

func _on_body_entered(body: Node2D) -> void:
	var inv: ItemReceiverComponent = body.get_node_or_null("ItemReceiverComponent")
	if inv: inv.add_to_in_range_queue(self)

func _on_area_exited(area: Area2D) -> void:
	var inv: ItemReceiverComponent = area.get_node_or_null("ItemReceiverComponent")
	if inv: inv.remove_from_in_range_queue(self)

func _on_body_exited(body: Node2D) -> void:
	var inv: ItemReceiverComponent = body.get_node_or_null("ItemReceiverComponent")
	if inv: inv.remove_from_in_range_queue(self)

func _set_item(item_stats: ItemResource) -> void:
	stats = item_stats
	if stats and icon:
		icon.texture = stats.icon
