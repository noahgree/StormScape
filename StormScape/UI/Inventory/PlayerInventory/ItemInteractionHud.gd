extends NinePatchRect
class_name ItemInteractionHUD

@onready var interact_text: Label = $InteractText
@onready var item_texture: TextureRect = $ItemTexture


func _ready() -> void:
	visible = false

func show_hud(item: Item) -> void:
	item_texture.texture = item.stats.icon
	visible = true

func hide_hud() -> void:
	visible = false
	item_texture.texture = null
