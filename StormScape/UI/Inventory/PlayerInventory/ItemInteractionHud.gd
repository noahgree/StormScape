extends NinePatchRect
class_name ItemInteractionHUD
## The HUD that shows a prompt for when the player can pick up an item.

@onready var item_texture: TextureRect = $ItemTexture ## The texture of the item to pickup.
@onready var quantity: Label = $Quantity ## The label showing the quantity of the item to pickup.
@onready var item_glow: TextureRect = $ItemGlow ## The glow texture behind the item that represents its rarity.


## Hides visibility at start.
func _ready() -> void:
	visible = false

## Shows the HUD after populating the appropriate item texture.
func show_hud(item: Item) -> void:
	item_texture.texture = item.stats.icon
	_update_glint(item.stats)
	quantity.text = str(item.quantity)
	visible = true

## Hides the HUD and clears the texture.
func hide_hud() -> void:
	visible = false
	item_texture.texture = null
	quantity.text = ""

func _update_glint(stats: ItemResource) -> void:
	item_texture.material.set_shader_parameter("outline_color", GlobalData.rarity_colors.outline_color.get(stats.rarity))
	item_texture.material.set_shader_parameter("tint_color", GlobalData.rarity_colors.tint_color.get(stats.rarity))
	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = Gradient.new()
	gradient_texture.gradient.add_point(0, GlobalData.rarity_colors.glint_color.get(stats.rarity))
	item_texture.material.set_shader_parameter("color_gradient", gradient_texture)
	if stats.rarity == GlobalData.ItemRarity.EPIC or stats.rarity == GlobalData.ItemRarity.LEGENDARY or  stats.rarity == GlobalData.ItemRarity.SINGULAR:
		item_glow.self_modulate = GlobalData.rarity_colors.slot_glow.get(stats.rarity)
	else:
		item_glow.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
