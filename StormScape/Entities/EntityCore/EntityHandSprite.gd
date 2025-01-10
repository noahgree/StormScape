@icon("res://Utilities/Debug/EditorIcons/entity_hand_sprite.svg")
extends Sprite2D
class_name EntityHandSprite
## A class for controlling entity hand sprites in order for them to properly sync up with the entity body's FX.

@export var _offset: Vector2: ## A copy of offset that responds to changes by moving the overlay to the new position.
	set(new_value):
		offset = new_value
		overlay.position = starting_overlay_pos + offset

@onready var overlay: ColorRect = $Overlay ## The overlay modifiying the hand's color.

var starting_overlay_pos: Vector2 ## The starting position of the overlay for use in _offset setter.
var source_entity_sprite: EntitySprite ## The sprite of the entity holding the equippable item that this hand is attached to.


func _ready() -> void:
	_offset = Vector2.ZERO
	_setup_signal_and_initial_color()

## Connects the color change signal and sets the initial overlay color.
func _setup_signal_and_initial_color() -> void:
	await get_tree().process_frame

	if owner is EquippableItem:
		source_entity_sprite = owner.source_entity.sprite
		texture = owner.source_entity.hands.hand_texture
		call_deferred("_setup_overlay_pos")
	elif owner is HandsComponent:
		source_entity_sprite = owner.entity.sprite
		texture = owner.entity.hands.hand_texture
		call_deferred("_setup_overlay_pos")
	else:
		assert(false, owner.name + " cannot have an EntityHandSprite instance as a descendant.")

	source_entity_sprite.overlay_changed.connect(_on_entity_sprite_overlay_changed)

	if not source_entity_sprite.current_sprite_glow_names.is_empty():
		var new_color: Color = source_entity_sprite.glow_colors.get(source_entity_sprite.current_sprite_glow_names[0], Color.WHITE)
		overlay.color = new_color

## Sets up the overlay position based on the hand size.
func _setup_overlay_pos() -> void:
	var hand_size: Vector2 = SpriteHelpers.SpriteDetails.get_frame_rect(self, false)

	overlay.size = hand_size
	overlay.position = Vector2(-hand_size.y * 0.5, -hand_size.x * 0.5)
	starting_overlay_pos = overlay.position

## Changes the overlay color on reception of the signal.
func _on_entity_sprite_overlay_changed(new_color: Color) -> void:
	overlay.color = new_color
