@icon("res://Utilities/Debug/EditorIcons/entity_hand_sprite.svg")
extends Sprite2D
class_name EntityHandSprite
## Syncs all hand textures for an entity.

var source_entity_sprite: EntitySprite ## The sprite of the entity holding the equippable item that this hand is attached to.


func _ready() -> void:
	_setup_texture()

## Gets the entity's hand texture.
func _setup_texture() -> void:
	await get_tree().process_frame

	if owner is EquippableItem:
		source_entity_sprite = owner.source_entity.sprite
		texture = owner.source_entity.hands.hand_texture
	elif owner is HandsComponent:
		source_entity_sprite = owner.entity.sprite
		texture = owner.entity.hands.hand_texture
	else:
		assert(false, owner.name + " cannot have an EntityHandSprite instance as a descendant.")
