@icon("res://Utilities/Debug/EditorIcons/interact_hud.svg")
extends NinePatchRect
class_name ItemInteractionHUD
## The HUD that shows a prompt for when the player can pick up an item.

@onready var pickup_preview_slot: Slot = %PickupPreviewSlot
@onready var quantity: Label = %ItemPickupQuantity
@onready var quantity_margins: MarginContainer = %QuantityMargins


func _ready() -> void:
	visible = false
	SignalBus.focused_ui_opened.connect(func() -> void: modulate.a = 0.0)
	SignalBus.focused_ui_closed.connect(func() -> void: modulate.a = 1.0)

## Shows the HUD after populating the appropriate item texture.
func show_hud(item: Item) -> void:
	pickup_preview_slot.preview_items = [{ InvItemResource.new(item.stats, item.quantity, true) : item.stats.rarity }]

	if item.quantity > 1:
		quantity.text = str(item.quantity)
	else:
		quantity.text = ""
	if item.quantity > 99:
		quantity_margins.add_theme_constant_override("margin_right", 0)
	else:
		quantity_margins.add_theme_constant_override("margin_right", 1)

	visible = true

## Hides the HUD and clears the texture.
func hide_hud() -> void:
	pickup_preview_slot.preview_items = []
	visible = false
