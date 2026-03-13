@tool
extends Sprite2D
class_name EntityShadow


@onready var sprite: EntitySprite = owner.get_node_or_null("%EntitySprite")


func _ready() -> void:
	if sprite == null:
		return

	scale = sprite.scale
	offset = sprite.position / sprite.scale

	sprite.frame_changed.connect(_set_new_texture)
	_set_new_texture()


func _set_new_texture() -> void:
	texture = SpriteHelpers.SpriteDetails.get_frame_texture(sprite)
