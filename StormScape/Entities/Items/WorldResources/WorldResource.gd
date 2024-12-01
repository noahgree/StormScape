extends EquippableItem
class_name WorldResource

@onready var sprite: Sprite2D = $Sprite2D


func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

	if sprite:
		sprite.texture = stats.thumbnail

func activate() -> void:
	pass
