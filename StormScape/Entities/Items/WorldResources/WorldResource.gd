extends EquippableItem
class_name WorldResource

@onready var sprite: Sprite2D = $Sprite2D

var s_stats: ItemResource ## Self stats, only exists to give us type hints for this specific kind of item resource.


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	s_stats = stats.duplicate()
	source_slot.synced_inv.update_an_item_stats(source_slot.index, s_stats)
	if sprite:
		sprite.texture = s_stats.thumbnail

func activate() -> void:
	pass
