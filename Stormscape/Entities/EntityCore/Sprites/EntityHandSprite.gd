@icon("res://Utilities/Debug/EditorIcons/entity_hand_sprite.svg")
extends Sprite2D
class_name EntityHandSprite
## Syncs all hand textures for an entity.

var hands: HandsComponent ## The hands component that drives this hand sprite.


func _ready() -> void:
	_setup_texture()

## Gets the entity's hand texture.
func _setup_texture() -> void:
	await get_tree().process_frame

	if owner is EquippableItem:
		hands = owner.source_entity.hands
	elif owner is HandsComponent:
		hands = owner.entity.hands
	else:
		assert(false, owner.name + " cannot have an EntityHandSprite instance as a descendant.")

	if hands:
		texture = hands.hand_texture
		if hands.time_brightness_min_max != Vector2(1.0, 1.0):
			DayNightManager.brightness_signal.connect(_on_day_night_brightness_tick)

## Interpolates the brightness mult on the modulate based on the brightness given by the day-night manager.
func _on_day_night_brightness_tick(progress: float) -> void:
	var brightness: float = hands.time_brightness_min_max.y + (hands.time_brightness_min_max.x - hands.time_brightness_min_max.y) * progress
	modulate = Color(1.0 * brightness, 1.0 * brightness, 1.0 * brightness, 1.0)
