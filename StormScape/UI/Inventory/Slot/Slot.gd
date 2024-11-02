@tool
extends NinePatchRect
class_name Slot

@onready var item_texture: TextureRect = $Button/TextureMargins/ItemTexture
@onready var quantity: Label = $QuantityMargins/Quantity

var item: InventoryItem:
	set(new_item):
		item = new_item
		if item:
			if item.stats.icon:
				item_texture.texture = item.stats.icon
			if item.quantity > 0:
				quantity.text = str(item.quantity)
			else:
				quantity.text = ""

func _to_string() -> String:
	return str(item)
