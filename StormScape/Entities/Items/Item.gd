extends Resource
class_name Item

@export var name: String
@export var icon: Texture2D

@export_enum("Weapon", "Clothing", "Consumable") var type: String
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

@export_multiline var info: String


func use_item() -> void:
	pass
