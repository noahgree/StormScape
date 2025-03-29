extends VBoxContainer
class_name CraftingManager
## Manages crafting actions like checking and caching recipes, consuming ingredients, and
## granting successful crafts.
##
## This also contains all the cached item resources that can be accessed by the item ID.

static var cached_items: Dictionary[StringName, ItemResource] = {} ## All items keyed by their unique item id.

@export_dir var tres_folder: String ## The folder path to all the TRES items.

@onready var output_slot: CraftingSlot = %OutputSlot ## The slot where the result will appear in.
@onready var input_slots_container: GridContainer = %InputSlots ## The container holding the input slots as children.
@onready var crafting_down_arrow: TextureRect = %CraftingDownArrow ## The arrow symbol.
@onready var craft_button: NinePatchRect = %Craft ## The nine patch background for the craft button.

var item_to_recipes: Dictionary[StringName, Array] = {} ## Maps items to the list of recipes that include them.
var tag_to_recipes: Dictionary[StringName, Array] = {} ## Maps tags to the list of recipes that include them.
var tag_to_items: Dictionary[StringName, Array] = {} ## Maps tags to the list of items that have that tag.
var input_slots: Array[CraftingSlot] = [] ## The slots that are used as inputs to craft.
var is_crafting: bool = false ## When true, we shouldn't update the output slot since a craft is in progress.
var item_details_panel: ItemDetailsPanel ## The item viewer panel that shows item details.


## Gets and returns an item resource by its id.
static func get_item_by_id(item_id: StringName) -> ItemResource:
	var item_resource: ItemResource = CraftingManager.cached_items.get(item_id, null)
	if item_resource == null:
		push_error("The CraftingManager did not have \"" + item_id + "\" in its cache.")
	return item_resource

func _ready() -> void:
	_cache_recipes()

	_on_output_slot_output_changed(false)
	output_slot.output_changed.connect(_on_output_slot_output_changed)
	SignalBus.focused_ui_closed.connect(_on_focused_ui_closed)

	call_deferred("_setup_slots")
	call_deferred("_setup_item_viewer_signals")

## This caches the items by their recipe ID at the start of the game.
func _cache_recipes() -> void:
	var dir: DirAccess = DirAccess.open(tres_folder)
	if dir == null:
		push_error("CraftingManager couldn't open the tres folder to cache the item recipes.")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path: String = tres_folder + "/" + file_name
			var item_resource: ItemResource = load(file_path)
			item_resource.session_uid = 0 # Triggers the setter func in the resource to make sure it's given an suid
			CraftingManager.cached_items[item_resource.id] = item_resource

			for tag: StringName in item_resource.tags:
				if not tag_to_items.has(tag):
					tag_to_items[tag] = []
				tag_to_items[tag].append(item_resource)

			for ingredient: CraftingIngredient in item_resource.recipe:
				if ingredient.type == "Item":
					var ingredient_recipe_id: StringName = ingredient.item.id
					if ingredient_recipe_id not in item_to_recipes:
						item_to_recipes[ingredient_recipe_id] = []
					item_to_recipes[ingredient_recipe_id].append(item_resource.id)
				elif ingredient.type == "Tags":
					for tag: StringName in ingredient.tags:
						if tag not in tag_to_recipes:
							tag_to_recipes[tag] = []
						tag_to_recipes[tag].append(item_resource.id)

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
	var inv: Inventory = Globals.player_node.inv
	var i: int = 0
	for input_slot: CraftingSlot in input_slots_container.get_children():
		input_slot.name = "Input_Slot_" + str(i)
		input_slot.synced_inv = inv
		input_slot.index = inv.inv_size + 1 + i # The 1 is for the trash slot
		input_slot.item_changed.connect(_on_input_item_changed)
		input_slots.append(input_slot)
		i += 1
	output_slot.name = "Output_Slot"
	output_slot.synced_inv = inv
	output_slot.index = inv.inv_size + 1 + i

## Sets up the item viewer node reference and the signals needed to respond to changes.
func _setup_item_viewer_signals() -> void:
	item_details_panel = get_parent().get_node("%ItemDetailsPanel")
	item_details_panel.item_viewer_slot.item_changed.connect(_on_viewed_item_changed)

## This processes the items in the input slots so that they can be worked with faster by
## the other crafting functions.
func _preprocess_selected_items() -> Dictionary[StringName, Dictionary]:
	var item_quantities: Dictionary[StringName, Array] = {}
	var tag_quantities: Dictionary[StringName, Array] = {}

	for slot: CraftingSlot in input_slots:
		if slot.item == null:
			continue

		var inv_item: InvItemResource = slot.item
		var item_id: StringName = inv_item.stats.id

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
			var str_ingredient: StringName = ingredient.item.id
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
func _check_rarity_condition(rarity_cond: String, req_rarity: Globals.ItemRarity,
							item_rarity: Globals.ItemRarity) -> bool:
	match rarity_cond:
		"No":
			return true
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
					if slot.item.stats.id == ingredient.item.id:
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

## When any of the input slot items change, we try and populate the previews once again just in case the mismatches
## were just removed. We also update the crafting result to see if our input items can result in a craft.
func _on_input_item_changed(_slot: CraftingSlot, _old_item: InvItemResource, _new_item: InvItemResource) -> void:
	await get_tree().process_frame
	_populate_previews(item_details_panel.item_viewer_slot.item)
	_update_crafting_result()

## Use candidate recipes for efficiency to only test the recipes that are even potentially craftable.
func _update_crafting_result() -> void:
	if is_crafting:
		return

	var candidates: Array[StringName] = _get_candidate_recipes()
	for recipe_id: StringName in candidates:
		var item_resource: ItemResource = CraftingManager.cached_items[recipe_id]
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
				if slot.item.stats.id == ingredient.item.id:
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
		Globals.player_node.inv.insert_from_inv_item(output_slot.item, false, false)

	is_crafting = false
	_update_crafting_result()

## When the main viewed item is changed, we wait for it to be set for a frame and then populate the previews
## with its recipe if we can.
func _on_viewed_item_changed(_slot: Slot, _old_item: InvItemResource, new_item: InvItemResource) -> void:
	await get_tree().process_frame
	_populate_previews(new_item)

## This checks if there are any mismatches in the input slots, and if not, it sets the preview items for all
## slots with no item.
func _populate_previews(item: InvItemResource) -> void:
	if _clear_preview_items_from_slots_unless_they_match_previewed_recipe_exactly() and item_details_panel.item_viewer_slot.item != null:
		_remove_altered_quantity_texts()
		return
	if item == null:
		_remove_altered_quantity_texts()
		return
	if not item.stats.recipe_unlocked:
		_remove_altered_quantity_texts()
		return

	var preview_array: Array[Array] = _get_preview_array(item)
	var i: int = 0
	for array: Array in preview_array:
		if input_slots[i].item == null:
			input_slots[i].preview_items = array
		i += 1

func _remove_altered_quantity_texts() -> void:
	for slot: CraftingSlot in input_slots:
		if slot.item != null:
			slot.quantity.self_modulate.a = 1.0
			var index: int = slot.quantity.text.rfind("/")
			if index != -1:
				slot.quantity.text = slot.quantity.text.substr(0, index)

## This gets the array of compatible items for each crafting ingredient in a recipe. Each ingredient can have
## more than one matching item if it is a "tag" ingredient. This is an array of arrays of Dictionaries, where
## the keys are the InvItemResources and the values are the minimum rarities. -1 min rarity means no min rarity.
func _get_preview_array(item: InvItemResource) -> Array[Array]:
	var preview_array: Array[Array] = []
	var recipe: Array[CraftingIngredient] = item.stats.recipe
	for ingredient: CraftingIngredient in recipe:
		var items_to_preview: Array[Dictionary]
		if ingredient.type == "Tags":
			for tag: StringName in ingredient.tags:
				var items_with_tag: Array = tag_to_items.get(tag, [])
				for item_with_tag: ItemResource in items_with_tag:
					items_to_preview.append({ InvItemResource.new(item_with_tag, ingredient.quantity, true) : 0 })
		elif ingredient.type == "Item":
			var min_rarity: int = 0
			if ingredient.rarity_match == "GEQ":
				min_rarity = ingredient.item.rarity
			items_to_preview.append({ InvItemResource.new(ingredient.item, ingredient.quantity, true) : min_rarity })

		preview_array.append(items_to_preview)

	return preview_array

## Checks if the items that are present in the input slots match up exactly with any existing preview items.
## If they all do, this returns false, indicating there was nothing wrong with the validation and nothing
## was cleared. If something is a mismatch, it returns true.
func _clear_preview_items_from_slots_unless_they_match_previewed_recipe_exactly() -> bool:
	if item_details_panel.item_viewer_slot.item != null:
		var preview_array: Array[Array] = _get_preview_array(item_details_panel.item_viewer_slot.item)
		var quant_strings: Dictionary[int, String] = {}
		var need_to_clear: bool = false
		var i: int = 0
		for input_slot: CraftingSlot in input_slots:
			if input_slot.item != null:
				var items_match_preview: bool = false
				var preview_items: Variant = ArrayHelpers.get_or_default(preview_array, i, null)
				if preview_items != null:
					for item_dict: Dictionary in preview_items:
						if input_slot.item.stats.id == item_dict.keys()[0].stats.id:
							if input_slot.item.stats.rarity >= item_dict.values()[0]:
								quant_strings[i] = (str(input_slot.item.quantity) + "/" + str(item_dict.keys()[0].quantity))

								items_match_preview = true
								break

				if not items_match_preview:
					need_to_clear = true
					break

			i += 1

		if not need_to_clear:
			for j: int in range(input_slots.size()):
				if quant_strings.has(j):
					input_slots[j].quantity.text = quant_strings[j]
					var slash_index: int = quant_strings[j].rfind("/")
					if not int(quant_strings[j].substr(0, slash_index)) >= int(quant_strings[j].substr(slash_index + 1, quant_strings[j].length())):
						input_slots[j].quantity.self_modulate.a = 0.72
			return false

	for slot: CraftingSlot in input_slots:
		if not slot.preview_items.is_empty():
			slot.preview_items = []
		if slot.item == null:
			slot.quantity.text = ""

	return true

## When the focused UI is closed, we should empty out the crafting input slots and drop them on the
## ground if the inventory is now full.
func _on_focused_ui_closed() -> void:
	for slot: CraftingSlot in input_slots:
		if slot.item != null:
			Globals.player_node.inv.insert_from_inv_item(slot.item, false, false)
			slot.item = null
