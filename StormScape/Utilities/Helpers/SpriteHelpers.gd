class_name SpriteHelpers
## A collection of reused sprite functions like getting the texture or size of a frame in an AnimatedSprite2D.


class SpriteDetails:
	static func get_frame_texture(sprite_node: Node2D) -> Texture2D:
		var sprite_texture: Texture2D = null
		if sprite_node is AnimatedSprite2D:
			sprite_texture = _get_anim_sprite_texture(sprite_node)
		elif sprite_node is Sprite2D:
			sprite_texture = sprite_node.texture
		return sprite_texture

	static func get_frame_rect(sprite_node: Node2D) -> Vector2:
		var sprite_texture: Texture2D = null
		if sprite_node is AnimatedSprite2D:
			sprite_texture = _get_anim_sprite_texture(sprite_node)
		elif sprite_node is Sprite2D:
			sprite_texture = sprite_node.texture
		return sprite_texture.get_size() * sprite_node.scale

	static func _get_anim_sprite_texture(anim_sprite: AnimatedSprite2D) -> Texture2D:
		var current_anim: String = anim_sprite.animation
		var current_frame: int = anim_sprite.frame
		return anim_sprite.sprite_frames.get_frame_texture(current_anim, current_frame)
