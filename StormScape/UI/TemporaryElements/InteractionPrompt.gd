extends Control
class_name InteractionPrompt
## The prompt that can be reused for any interaction the player can accept.

@onready var title_label: Label = %InteractionTitleLabel ## The title label.
@onready var info_label: Label = %InteractionInfoLabel ## The information label.
@onready var icon_rect: TextureRect = %InteractionPromptIcon ## The prompt icon.
@onready var icon_margin: MarginContainer = %InteractionIconMargin ## The prompt icon margins.
@onready var text_margins: MarginContainer = %InteractionTextMargins ## The margins for all the interaction labels.

func _ready() -> void:
	hide()
	SignalBus.focused_ui_opened.connect(hide)

## Updates the prompt text labels and changes visibilities & margins accordingly.
func _update_text(interaction_offer: InteractionOffer) -> void:
	title_label.text = interaction_offer.title
	title_label.label_settings.font_color = interaction_offer.title_color
	title_label.label_settings.outline_color = interaction_offer.title_outline_color
	info_label.text = interaction_offer.info
	info_label.label_settings.font_color = interaction_offer.info_color
	info_label.label_settings.outline_color = interaction_offer.info_outline_color

	title_label.visible = title_label.text != ""
	info_label.visible = info_label.text != ""

## Updates the prompt interaction icon and changes visibilities accordingly.
func _update_icon(icon: Texture2D) -> void:
	icon_rect.texture = icon
	icon_margin.visible = icon != null

	text_margins.add_theme_constant_override("margin_right", 3 if icon != null else 2)

## Update the information and icon, resize appropriately, then show.
func update_and_show(interaction_offer: InteractionOffer) -> void:
	_update_text(interaction_offer)
	_update_icon(interaction_offer.icon)

	size = Vector2(0, 0) # Force a size recalculation
	var bottom_center: Vector2 = Vector2(size.x / 2.0, size.y)
	if is_instance_valid(interaction_offer.ui_anchor_node) and interaction_offer.ui_anchor_node.is_inside_tree():
		global_position = interaction_offer.ui_anchor_node.global_position + interaction_offer.ui_offset - bottom_center
		show()
