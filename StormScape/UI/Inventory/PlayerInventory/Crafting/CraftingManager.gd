extends VBoxContainer
class_name CraftingManager
## Manages crafting actions like checking and caching recipes, consuming ingredients, and
## granting successful crafts.

@export_dir var tres_folder: String ## The folder path to all the TRES items.

@onready var output_slot: CraftingSlot = %OutputSlot ## The slot where the result will appear in.
@onready var input_slots_container: GridContainer = %InputSlots ## The container holding the input slots as children.
@onready var crafting_down_arrow: TextureRect = %CraftingDownArrow ## The arrow symbol.
@onready var craft_button: NinePatchRect = %Craft ## The nine patch background for the craft button.

var cached_recipes: Dictionary[StringName, ItemResource] = {} ## All items keyed by their unique recipe id.
var item_to_recipes: Dictionary[StringName, Array] = {} ## Maps items to the list of recipes that include them.
var tag_to_recipes: Dictionary[StringName, Array] = {} ## Maps tags to the list of recipes that include them.
var input_slots: Array[CraftingSlot] = [] ## The slots that are used as inputs to craft.
var is_crafting: bool = false ## When true, we shouldn't update the output slot since a craft is in progress.


func _ready() -> void:
	_cache_recipes()

	_on_output_slot_output_changed(false)
	output_slot.output_changed.connect(_on_output_slot_output_changed)
	SignalBus.focused_ui_closed.connect(_on_focused_ui_closed)

	call_deferred("_setup_slots")

## This caches the items by their recipe ID at the start of the game.
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
			var item_resource: ItemResource = load(file_path)
			item_resource.session_uid = 0 # Triggers the setter func in the resource to make sure it's given an suid
			cached_recipes[item_resource.get_recipe_id()] = item_resource

			for ingredient: CraftingIngredient in item_resource.recipe:
				if ingredient.type == "Item":
					var ingredient_recipe_id: StringName = ingredient.item.get_recipe_id()
					if ingredient_recipe_id not in item_to_recipes:
						item_to_recipes[ingredient_recipe_id] = []
					item_to_recipes[ingredient_recipe_id].append(item_resource.get_recipe_id())
				elif ingredient.type == "Tags":
					for tag: StringName in ingredient.tags:
						if tag not in tag_to_recipes:
							tag_to_recipes[tag] = []
						tag_to_recipes[tag].append(item_resource.get_recipe_id())

		file_name = dir.get_next()
	dir.list_dir_end()

## Shows or hides the main craft button depending on whether a valid output is present.
func _on_output_slot_output_changed(is_craftable: bool) -> void:
	if is_craftable:
		craft_button.modulate = Color.WHITE
		craft_button.modulate.a = 1.0
		craft_button.get_node("CraftBtn").disabled = false
		crafting_down_arrow.modulate.a = 0.65
	else:
		craft_button.modulate = Color.LIGHT_GRAY
		craft_button.modulate.a = 0.5
		craft_button.get_node("CraftBtn").disabled = true
		crafting_down_arrow.modulate.a = 0.2

## Sets up the input and output slots with their needed data.
func _setup_slots() -> void:
	var inv: Inventory = GlobalData.player_node.inv
	var i: int = 0
	for input_slot: CraftingSlot in input_slots_container.get_children():
		input_slot.name = "Input_Slot_" + str(i)
		input_slot.synced_inv = inv
		input_slot.index = inv.inv_size + 1 + i # The 1 is for the trash slot
		input_slot.item_changed.connect(_update_crafting_result)
		input_slots.append(input_slot)
		i += 1
	output_slot.name = "Output_Slot"
	output_slot.synced_inv = inv
	output_slot.index = inv.inv_size + 1 + i

## This processes the items in the input slots so that they can be worked with faster by
## the other crafting functions.
func _preprocess_selected_items() -> Dictionary[StringName, Dictionary]:
	var item_quantities: Dictionary[StringName, Array] = {}
	var tag_quantities: Dictionary[StringName, Array] = {}

	for slot: CraftingSlot in input_slots:
		if slot.item == null:
			continue

		var inv_item: InvItemResource = slot.item
		var item_id: StringName = inv_item.stats.get_recipe_id()

		if item_id in item_quantities:
			item_quantities[item_id].append([inv_item.quantity, inv_item.stats.rarity])
		else:
			item_quantities[item_id] = [[inv_item.quantity, inv_item.stats.rarity]]

		for tag: StringName in inv_item.stats.tags:
			if tag in tag_quantities:
				tag_quantities[tag].append([inv_item.quantity, inv_item.stats.rarity])
			else:
				tag_quantities[tag] = [[inv_item.quantity, inv_item.stats.rarity]]

	return {&"items": item_quantities, &"tags": tag_quantities}

## This checks to see if a passed-in item is craftable based on what we have in our input slots.
func _is_item_craftable(item: ItemResource) -> bool:
	var recipe: Array[CraftingIngredient] = item.recipe
	var quantities: Dictionary[StringName, Dictionary] = _preprocess_selected_items()
	var item_quantities: Dictionary[StringName, Array] = quantities.items
	var tag_quantities: Dictionary[StringName, Array] = quantities.tags

	for ingredient: CraftingIngredient in recipe:
		var total_quantity: int = 0

		if ingredient.type == "Item":
			var str_ingredient: StringName = ingredient.item.get_recipe_id()
			if str_ingredient in item_quantities:
				for entry: Array in item_quantities[str_ingredient]:
					if _check_rarity_condition(ingredient.rarity_match, ingredient.item.rarity, entry[1]):
						total_quantity += entry[0]
		elif ingredient.type == "Tags":
			for tag: StringName in ingredient.tags:
				if tag in tag_quantities:
					for entry: Array in tag_quantities[tag]:
						total_quantity += entry[0]

		if total_quantity < ingredient.quantity:
			return false

	if not _verify_exact_match(recipe):
		return false

	return true

## This verifies that rarities match for ingredients if they are required to do so.
func _check_rarity_condition(rarity_cond: String, req_rarity: GlobalData.ItemRarity,
							item_rarity: GlobalData.ItemRarity) -> bool:
	match rarity_cond:
		"No":
			return true
		"Direct":
			return req_rarity == item_rarity
		"GEQ":
			return item_rarity >= req_rarity
	return false

## This verifies that each slot contains something that contributes to the recipe.
func _verify_exact_match(recipe: Array[CraftingIngredient]) -> bool:
	for slot: CraftingSlot in input_slots:
		if slot.item != null:
			var allowed: bool = false
			for ingredient: CraftingIngredient in recipe:
				if ingredient.type == "Item":
					if slot.item.stats.get_recipe_id() == ingredient.item.get_recipe_id():
						allowed = true
						break
				elif ingredient.type == "Tags":
					for tag: StringName in ingredient.tags:
						if tag in slot.item.stats.tags:
							allowed = true
							break
					if allowed:
						break

			if not allowed:
				return false
	return true

## Use the inverted lookups to get candidate recipes from the current items in the input.
func _get_candidate_recipes() -> Array:
	var quantities: Dictionary[StringName, Dictionary] = _preprocess_selected_items()
	var candidates: Dictionary[StringName, bool] = {}

	for item_id: StringName in quantities[&"items"].keys():
		if item_to_recipes.has(item_id):
			for recipe_id: StringName in item_to_recipes[item_id]:
				candidates[recipe_id] = true

	for tag: StringName in quantities[&"tags"].keys():
		if tag_to_recipes.has(tag):
			for recipe_id: StringName in tag_to_recipes[tag]:
				candidates[recipe_id] = true

	return candidates.keys()

## Use candidate recipes for efficiency to only test the recipes that are even potentially craftable.
func _update_crafting_result(_slot: CraftingSlot, _old_item: InvItemResource, _new_item: InvItemResource) -> void:
	if is_crafting:
		return

	var candidates: Array[StringName] = _get_candidate_recipes()
	for recipe_id: StringName in candidates:
		var item_resource: ItemResource = cached_recipes[recipe_id]
		if _is_item_craftable(item_resource):
			output_slot.item = InvItemResource.new(item_resource, item_resource.output_quantity)
			return

	output_slot.item = null

## This consumes the ingredients in the recipe once the item is claimed.
## If it fails, it restores all quantities and returns false.
func _consume_recipe(recipe: Array[CraftingIngredient]) -> bool:
	var initial_quantities: Array[int] = []
	for slot: CraftingSlot in input_slots:
		if slot.item != null:
			initial_quantities.append(slot.item.quantity)
		else:
			initial_quantities.append(-1)

	for ingredient: CraftingIngredient in recipe:
		var needed: int = ingredient.quantity

		for slot: CraftingSlot in input_slots:
			if slot.item == null:
				continue

			if ingredient.type == "Item":
				if slot.item.stats.get_recipe_id() == ingredient.item.get_recipe_id():
					if _check_rarity_condition(ingredient.rarity_match, ingredient.item.rarity, slot.item.stats.rarity):
						var available: int = slot.item.quantity
						var remove_amount: int = min(available, needed)
						slot.item = InvItemResource.new(slot.item.stats, available - remove_amount)
						needed -= remove_amount
			elif ingredient.type == "Tags":
				for tag: StringName in ingredient.tags:
					if tag in slot.item.stats.tags:
						var available: int = slot.item.quantity
						var remove_amount: int = min(available, needed)
						slot.item = InvItemResource.new(slot.item.stats, available - remove_amount)
						needed -= remove_amount
						break

		if needed > 0:
			for i: int in range(input_slots.size()):
				if input_slots[i].item != null:
					input_slots[i].item.quantity = initial_quantities[i]
			return false
		else:
			for slot: CraftingSlot in input_slots:
				if slot.item != null:
					if slot.item.quantity <= 0:
						slot.item = null

	return true

## This attempts to craft what is shown in the output slot by consuming the ingredients and
## granting the output item.
func attempt_craft() -> void:
	is_crafting = true

	if _consume_recipe(output_slot.item.stats.recipe):
		GlobalData.player_node.inv.insert_from_inv_item(output_slot.item, false, false)

	is_crafting = false
	_update_crafting_result(null, null, null)

## When the focused UI is closed, we should empty out the crafting input slots and drop them on the
## ground if the inventory is now full.
func _on_focused_ui_closed() -> void:
	for slot: CraftingSlot in input_slots:
		if slot.item != null:
			GlobalData.player_node.inv.insert_from_inv_item(slot.item, false, false)
			slot.item = null
