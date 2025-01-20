extends Area2D
class_name Inventory
## The main superclass for any inventory controller.

signal slot_updated(index: int, item: InvItemResource)

@export var item_scene: PackedScene = preload("res://Entities/Items/ItemCore/Item.tscn") ## The item scene to be used when items are instantiated on the ground.
@export var starting_inv: Array[InvItemResource] ## The inventory that should be loaded when this scene is instantiated.
@export var is_player_inv: bool = false ## Whether this is the player's inventory or not. Needed for hotbar and trash slot logic.
@export var inv_size: int = 32 ## The total number of slots in the inventory, including the hotbar slots.
@export var hotbar_size: int = 0 ## The number of slots out of the inv_size that are in the hotbar. Only affects the player inv.
@export var inv_populator: InventoryPopulator ## The control node that is responsible for populating its connected slots.
@export var ui: InventoryUI ## The parent control node that contains all inventory UI nodes as children.

@onready var auto_decrementer: AutoDecrementer = AutoDecrementer.new() ## The script controlling the cooldowns, warmups, overheats, and recharges for this entity's inventory items.

var inv: Array[InvItemResource] = [] ## The current inventory. Main source of truth.
var inv_to_load_from_save: Array[InvItemResource] = [] ## Gets loaded when a game is loaded so that it can be iterated into the main inv array.


## Sets up the connected UI and populator after resizing the inv array appropriately.
func _ready() -> void:
	if not is_player_inv:
		hotbar_size = 0
	inv.resize(inv_size if not is_player_inv else inv_size + 1) # For trash slot
	inv_populator.connect_inventory(self)
	ui.connect_inventory(self)
	call_deferred("fill_inventory", starting_inv)

	if is_player_inv:
		auto_decrementer.owning_entity_is_player = true
	auto_decrementer.inv = self

func _process(delta: float) -> void:
	auto_decrementer.process(delta)

## Fills the main inventory from an array of inventory items. If an item exceeds stack size, the quantity that does not fit into ## one slot is instantiated on the ground as a physical item. This method respects null spots in the list.
func fill_inventory(inv_to_fill_from: Array[InvItemResource]) -> void:
	inv.fill(null)

	for i: int in range(min(inv_size if not is_player_inv else inv_size + 1, inv_to_fill_from.size())):
		if inv_to_fill_from[i] == null:
			inv[i] = null
		else:
			var inv_item: InvItemResource = inv_to_fill_from[i].duplicate()

			if inv_item.quantity > inv_item.stats.stack_size:
				Item.spawn_on_ground(inv_item.stats, inv_item.quantity - inv_item.stats.stack_size, global_position, 14.0, true)
				inv_item.quantity = inv_item.stats.stack_size

			inv[i] = inv_item

	_update_all_connected_slots()

## Fills the main inventory from an array of inventory items. Calls another method to check stack size conditions, filling
## iteratively. It does not drop excess items on the ground, and anything that does not fit will be ignored.
func fill_inventory_with_checks(inv_to_fill_from: Array[InvItemResource]) -> void:
	inv.fill(null)

	for i: int in range(min(inv_size if not is_player_inv else inv_size + 1, inv_to_fill_from.size())):
		if inv_to_fill_from[i] != null:
			add_item_from_inv_item_resource(inv_to_fill_from[i])

	_update_all_connected_slots()

## Handles the logic needed for adding an item to the inventory when picked up from the ground. Respects stack size.
## Any extra quantity that does not fit will be left on the ground as a physical item.
func add_item_from_world(item: Item) -> bool:
	var inv_item: InvItemResource = InvItemResource.new(item.stats, item.quantity)
	for i: int in range(hotbar_size):
		var result: String = _do_add_item_checks(i + (inv_size - hotbar_size), inv_item, item)
		if result == "done":
			return true
		elif result == "new inv item created":
			inv_item = InvItemResource.new(item.stats, item.quantity)
	for i: int in range(inv_size - hotbar_size):
		var result: String = _do_add_item_checks(i, inv_item, item)
		if result == "done":
			return true
		elif result == "new inv item created":
			inv_item = InvItemResource.new(item.stats, item.quantity)
	return false

## Handles the logic needed for adding an item to the inventory from a given inventory item resource. Respects stack size.
## Any extra quantity that does not fit will be ignored and deleted.
func add_item_from_inv_item_resource(original_item: InvItemResource) -> bool:
	var inv_item: InvItemResource = InvItemResource.new(original_item.stats, original_item.quantity)
	for i: int in range(inv_size):
		var result: String = _do_add_item_checks(i, inv_item, original_item)
		if result == "done":
			return true
		elif result == "new inv item created":
			inv_item = InvItemResource.new(original_item.stats, original_item.quantity)
	return false

## Wrapper function to let child functions check whether to add quantity to an item slot. Returns a string based on what it did.
func _do_add_item_checks(index: int, inv_item: InvItemResource, item: Variant) -> String:
	if inv[index] != null and inv[index].stats.is_same_as(inv_item.stats):
		if (inv_item.quantity + inv[index].quantity) <= inv_item.stats.stack_size:
			_combine_item_count_in_occupied_slot(index, inv_item, item)
			return "done"
		else:
			_add_what_fits_to_occupied_slot_and_continue(index, inv_item, item)
	if inv[index] == null:
		if inv_item.quantity <= inv_item.stats.stack_size:
			_put_entire_quantity_in_empty_slot(index, inv_item, item)
			return "done"
		else:
			_put_what_fits_in_empty_slot_and_continue(index, inv_item, item)
			return "new inv item created"
	return ""

## Combines the item into a slot that has space for that kind of item.
func _combine_item_count_in_occupied_slot(index: int, inv_item: InvItemResource, original_item: Variant) -> void:
	inv[index].quantity += inv_item.quantity
	if original_item is Item: original_item.remove_from_world()
	slot_updated.emit(index, inv[index])

## Adds what fits to an occupied slot of the same kind of item and passes the remainder to the next iteration.
func _add_what_fits_to_occupied_slot_and_continue(index: int, inv_item: InvItemResource, original_item: Variant) -> void:
	var amount_that_fits: int = max(0, inv_item.stats.stack_size - inv[index].quantity)
	inv[index].quantity = inv_item.stats.stack_size
	inv_item.quantity -= amount_that_fits
	original_item.quantity -= amount_that_fits
	slot_updated.emit(index, inv[index])

## Puts the entire quantity of the given item into an empty slot. This means it was less than or equal to stack size.
func _put_entire_quantity_in_empty_slot(index: int, inv_item: InvItemResource, original_item: Variant) -> void:
	inv[index] = inv_item
	if original_item is Item: original_item.remove_from_world()
	slot_updated.emit(index, inv[index])

## This puts what fits of an item type into an empty slot and passes the remainder to the next iteration.
func _put_what_fits_in_empty_slot_and_continue(index: int, inv_item: InvItemResource, original_item: Variant) -> void:
	var leftover: int = max(0, inv_item.quantity - inv_item.stats.stack_size)
	inv_item.quantity = inv_item.stats.stack_size
	inv[index] = inv_item
	original_item.quantity = leftover
	slot_updated.emit(index, inv[index])

func remove_item(index: int, amount: int) -> void:
	var updated_item: InvItemResource = InvItemResource.new(inv[index].stats, inv[index].quantity)
	updated_item.quantity = max(0, updated_item.quantity - amount)
	inv[index] = updated_item
	if updated_item.quantity <= 0:
		inv[index] = null
	slot_updated.emit(index, inv[index])

## This updates all connected slots in order to reflect the UI properly.
func _update_all_connected_slots() -> void:
	for i: int in range(inv_size):
		slot_updated.emit(i, inv[i])
	if is_player_inv:
		slot_updated.emit(inv_size, inv[inv_size]) # For trash slot

#region Sorting
## This auto stacks and compacts items into their stack sizes.
func activate_auto_stack() -> void:
	for i: int in range(inv_size - hotbar_size):
		if inv[i] == null:
			continue
		for j: int in range(i + 1, inv_size - hotbar_size):
			if inv[j] == null:
				continue
			if inv[i].stats.is_same_as(inv[j].stats):
				var total_quantity: int = inv[i].quantity + inv[j].quantity
				if total_quantity <= inv[i].stats.stack_size:
					inv[i].quantity = total_quantity
					inv[j] = null
				else:
					inv[i].quantity = inv[i].stats.stack_size
					inv[j].quantity = total_quantity - inv[i].stats.stack_size

	_update_all_connected_slots()

## Called in order to start sorting by rarity of items in the inventory. Does not sort hotbar if present.
func activate_sort_by_rarity() -> void:
	var arr: Array[InvItemResource] = inv.slice(0, inv_size - hotbar_size)
	arr.sort_custom(_rarity_sort_logic)
	for i: int in range(inv_size - hotbar_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

## Called in order to start sorting by type of items in the inventory. Does not sort hotbar if present.
func activate_sort_by_type() -> void:
	var arr: Array[InvItemResource] = inv.slice(0, inv_size - hotbar_size)
	arr.sort_custom(_type_sort_logic)
	for i: int in range(inv_size - hotbar_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

## Called in order to start sorting by name of items in the inventory. Does not sort hotbar if present.
func activate_sort_by_name() -> void:
	var arr: Array[InvItemResource] = inv.slice(0, inv_size - hotbar_size)
	arr.sort_custom(_name_sort_logic)
	for i: int in range(inv_size - hotbar_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

## Implements the comparison logic for sorting by rarity.
func _rarity_sort_logic(a: InvItemResource, b: InvItemResource) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.rarity != b.stats.rarity:
		return a.stats.rarity > b.stats.rarity
	else:
		return a.stats.name < b.stats.name

## Implements the comparison logic for sorting by item type.
func _type_sort_logic(a: InvItemResource, b: InvItemResource) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.item_type != b.stats.item_type:
		return a.stats.item_type > b.stats.item_type
	else:
		return a.stats.name < b.stats.name

## Implements the comparison logic for sorting by name.
func _name_sort_logic(a: InvItemResource, b: InvItemResource) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.name != b.stats.name:
		return a.stats.name < b.stats.name
	else:
		return a.quantity < b.quantity
#endregion

#region Projectile Weapon Helpers
func get_more_ammo(max_amount_needed: int, take_from_inventory: bool, ammo_type: ProjWeaponResource.ProjAmmoType) -> int:
	var ammount_collected: int = 0

	for i: int in range(inv_size):
		var item: InvItemResource = inv[i]
		if item != null and (item.stats is ProjAmmoResource) and (item.stats.ammo_type == ammo_type):
			var amount_in_slot: int = item.quantity
			var amount_still_needed: int = max_amount_needed - ammount_collected
			var amount_to_take_from_slot: int = min(amount_still_needed, amount_in_slot)
			if take_from_inventory:
				remove_item(i, amount_to_take_from_slot)
			ammount_collected += amount_to_take_from_slot

			if ammount_collected == max_amount_needed:
				break

	return ammount_collected
#endregion

#region Debug
## Custom method for printing the rich details of all inventory array spots.
func print_inv(include_null_spots: bool = false) -> void:
	var to_print: String = "[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]\n"
	for i: int in range(inv_size):
		if inv[i] == null and not include_null_spots:
			continue
		to_print = to_print + str(inv[i]) + str(inv[i].stats.get_cooldown_id())
		if (i + 1) % 5 == 0 and i != inv_size - 1: to_print += "\n"
		elif i != inv_size - 1: to_print += "  |  "
	if to_print.ends_with("\n"): to_print = to_print.substr(0, to_print.length() - 1)
	elif to_print.ends_with("|  "): to_print = to_print.substr(0, to_print.length() - 3)
	print_rich(to_print + "\n[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]")
#endregion
