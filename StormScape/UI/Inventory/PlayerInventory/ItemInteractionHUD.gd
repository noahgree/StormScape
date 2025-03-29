extends NinePatchRect
class_name ItemInteractionHUD
## The HUD that shows a prompt for when the player can pick up an item.

@onready var texture_margins: MarginContainer = $TextureMargins
@onready var item_texture: TextureRect = $TextureMargins/ItemTexture ## The texture of the item to pickup.
@onready var quantity: Label = $Quantity ## The label showing the quantity of the item to pickup.
@onready var item_glow: TextureRect = $ItemGlow ## The glow texture behind the item that represents its rarity.


## Hides visibility at start.
func _ready() -> void:
	visible = false
	SignalBus.focused_ui_opened.connect(func() -> void: modulate.a = 0.0)
	SignalBus.focused_ui_closed.connect(func() -> void: modulate.a = 1.0)

## Shows the HUD after populating the appropriate item texture.
func show_hud(item: Item) -> void:
	item_texture.texture = item.stats.inv_icon
	texture_margins.position = Vector2(16, 0)
	texture_margins.rotation_degrees = item.stats.inv_icon_rotation

	_update_glint(item.stats)
	quantity.text = str(item.quantity)
	visible = true

## Hides the HUD and clears the texture.
func hide_hud() -> void:
	visible = false
	item_texture.texture = null
	quantity.text = ""

func _update_glint(stats: ItemResource) -> void:
	var outline_width: float = (0.5 * (max(item_texture.texture.get_width(), item_texture.texture.get_height()) / 16.0))
	item_texture.material.set_shader_parameter("width", outline_width)

	item_texture.material.set_shader_parameter("outline_color", Globals.rarity_colors.outline_color.get(stats.rarity))
	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = Gradient.new()
	gradient_texture.gradient.add_point(0, Globals.rarity_colors.glint_color.get(stats.rarity))
	item_texture.material.set_shader_parameter("color_gradient", gradient_texture)

	item_glow.self_modulate = Globals.rarity_colors.slot_glow.get(stats.rarity)
