extends Node2D
class_name EquippableItem

@export var stats: ItemResource = null: set = _set_stats ## The resource driving the stats and type of item.
@export var is_gripped_by_one_hand: bool = true

var source_slot: Slot

func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats

func _ready() -> void:
	_set_stats(stats)

func activate(_source_entity: PhysicsBody2D = null) -> void:
	pass
