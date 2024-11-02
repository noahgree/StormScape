extends Resource
class_name ItemResource

@export var name: String
@export var icon: Texture2D

@export var type: GlobalData.ItemType = GlobalData.ItemType.CONSUMABLE
@export var rarity: GlobalData.ItemRarity = GlobalData.ItemRarity.COMMON

@export var stack_size: int = 1

@export_multiline var info: String


func use_item() -> void:
	pass

func _to_string() -> String:
	return str(GlobalData.ItemType.keys()[type]) + ": " + str(GlobalData.ItemRarity.keys()[rarity]) + "_" + name

func is_same_as(other_item: ItemResource) -> bool:
	return (name == other_item.name) and (type == other_item.type) and (rarity == other_item.rarity)
