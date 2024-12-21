extends Node
class_name CraftingManager

@export_dir var tres_folder: String
@export var selected_items: Array[InvItemResource] = []

var cached_recipes: Dictionary = {}


func _ready() -> void:
	_cache_recipes()

func _cache_recipes() -> void:
	var dir: DirAccess = DirAccess.open(tres_folder)
	if dir == null:
		push_error("Crafting Manager couldn't open the tres folder to cache the item recipes.")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path: String = tres_folder + "/" + file_name
			var item: ItemResource = load(file_path)
			item.session_uid = 0 # This triggers the setter function inside the item resource to make sure its given an suid
			var recipe: Array[CraftingIngredient] = item.recipe
			cached_recipes[item.get_recipe_id()] = recipe
		file_name = dir.get_next()
	dir.list_dir_end()

func _preprocess_selected_items() -> Dictionary:
	var item_quantities: Dictionary = {}
	var tag_quantities: Dictionary = {}

	for inv_item: InvItemResource in selected_items:
		var item_id: String = inv_item.stats.get_recipe_id()
		if item_id in item_quantities:
			item_quantities[item_id].append([inv_item.quantity, inv_item.stats.rarity])
		else:
			item_quantities[item_id] = [[inv_item.quantity, inv_item.stats.rarity]]

		for tag: String in inv_item.stats.tags:
			if tag in tag_quantities:
				tag_quantities[tag].append([inv_item.quantity, inv_item.stats.rarity])
			else:
				tag_quantities[tag] = [[inv_item.quantity, inv_item.stats.rarity]]

	return {"items": item_quantities, "tags": tag_quantities}

func is_recipe_craftable(recipe: Array[CraftingIngredient]) -> bool:
	var quantities: Dictionary = _preprocess_selected_items()
	var item_quantities: Dictionary = quantities.items
	var tag_quantities: Dictionary = quantities.tags

	for ingredient: CraftingIngredient in recipe:
		var total_quantity: int = 0
		var str_ingredient: String = ingredient.item.get_recipe_id()

		if ingredient.type == "Item":
			if str_ingredient in item_quantities:
				for entry: Array in item_quantities[str_ingredient]:
					if _check_rarity_condition(ingredient.rarity_match, ingredient.item.rarity, entry[1]):
						total_quantity += entry[0]
		elif ingredient.type == "Tags":
			for tag: String in ingredient.tags:
				if tag in tag_quantities:
					for entry: Array in tag_quantities[tag]:
						if _check_rarity_condition(ingredient.rarity_match, ingredient.item.rarity, entry[1]):
							total_quantity += entry[0]

		if total_quantity < ingredient.quantity:
			return false

	return true

func _check_rarity_condition(rarity_cond: String, req_rarity: GlobalData.ItemRarity, item_rarity: GlobalData.ItemRarity) -> bool:
	match rarity_cond:
		"No":
			return true
		"Direct":
			return req_rarity == item_rarity
		"GEQ":
			return item_rarity >= req_rarity
	return false
