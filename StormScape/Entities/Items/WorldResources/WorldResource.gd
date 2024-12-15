extends EquippableItem
class_name WorldResource


func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

	if sprite:
		sprite.texture = stats.in_hand_icon

func activate() -> void:
	pass
