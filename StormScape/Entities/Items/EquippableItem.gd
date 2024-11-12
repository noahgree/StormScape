extends Node2D
class_name EquippableItem

@export var stats: ItemResource = null: set = _set_stats ## The resource driving the stats and type of item.
@export var is_gripped_by_one_hand: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats

func _ready() -> void:
	_set_stats(stats)
