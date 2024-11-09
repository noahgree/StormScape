extends NinePatchRect
class_name ItemInteractionHUD
## The HUD that shows a prompt for when the player can pick up an item.

@onready var interact_text: Label = $InteractText ## The text that tells what to press to pickup the item.
@onready var item_texture: TextureRect = $ItemTexture ## The texture of the item to pickup.


## Hides visibility at start.
func _ready() -> void:
	visible = false

## Shows the HUD after populating the appropriate item texture.
func show_hud(item: Item) -> void:
	item_texture.texture = item.stats.icon
	visible = true

## Hides the HUD and clears the texture.
func hide_hud() -> void:
	visible = false
	item_texture.texture = null
