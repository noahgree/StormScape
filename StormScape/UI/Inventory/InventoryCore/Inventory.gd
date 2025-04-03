@tool
extends Area2D
class_name Inventory
## The main inventory controller for all inventory data.

signal slot_updated(index: int, item: InvItemResource) ## Emitted anytime the item in a slot is set.

@export var is_player_inv: bool = false ## Whether this is the player's inventory or not. Needed for hotbar and trash slot logic.
@export var main_inv_size: int = 32 ## The total number of slots in the inventory, not including the hotbar slots or the trash slot if it exists. Must match main slot grid count on any connected UI.
@export var hotbar_size: int = 0: ## The number of slots in the hotbar. Only changeable if this is the player inv.
	set(new_value):
		if is_player_inv:
			hotbar_size = new_value
		else:
			hotbar_size = 0
@export var starting_inv: Array[InvItemResource] ## The inventory that should be loaded when this scene is instantiated.

@onready var auto_decrementer: AutoDecrementer = AutoDecrementer.new() ## The script controlling the cooldowns, warmups, overheats, and recharges for this entity's inventory items.

var inv: Array[InvItemResource] = [] ## The current inventory. Main source of truth.
var inv_to_load_from_save: Array[InvItemResource] = [] ## Gets loaded when a game is loaded so that it can be iterated into the main inv array.
var total_inv_size: int ## Number of all slots, including main slots, hotbar slots, and the potential trash slot.s


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	total_inv_size = main_inv_size + hotbar_size + (1 if is_player_inv else 0)
	inv.resize(total_inv_size)

	if is_player_inv:
		auto_decrementer.owning_entity_is_player = true
	auto_decrementer.inv = self

	call_deferred("fill_inventory", starting_inv)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	auto_decrementer.process(delta)

## Fills the main inventory from an array of inventory items. If an item exceeds stack size, the
## quantity that does not fit into one slot is instantiated on the ground as a physical item.
## This method respects null spots in the list.
func fill_inventory(inv_to_fill_from: Array[InvItemResource]) -> void:
	inv.fill(null)
	for i: int in range(min(total_inv_size, inv_to_fill_from.size())):
		if inv_to_fill_from[i] == null:
			inv[i] = null
		else:
			var copy: InvItemResource = inv_to_fill_from[i].duplicate()
			var inv_item: InvItemResource = InvItemResource.new(copy.stats, inv_to_fill_from[i].quantity) # Need to use new() so that it initializes

			if inv_item.quantity > inv_item.stats.stack_size:
				Item.spawn_on_ground(inv_item.stats, inv_item.quantity - inv_item.stats.stack_size, global_position, 14.0, true, false, true)
				inv_item.quantity = inv_item.stats.stack_size

			inv[i] = inv_item

	_update_all_connected_slots()

## Fills the main inventory from an array of inventory items. Calls another method to check
## stack size conditions, filling iteratively. It does not drop excess items on the ground,
## and anything that does not fit will be ignored.
func fill_inventory_with_checks(inv_to_fill_from: Array[InvItemResource]) -> void:
	inv.fill(null)
	for i: int in range(min(total_inv_size, inv_to_fill_from.size())):
		if inv_to_fill_from[i] != null:
			insert_from_inv_item(inv_to_fill_from[i], true, false)

	_update_all_connected_slots()

## Handles the logic needed for adding an item to the inventory when picked up from the ground. Respects stack size.
## Any extra quantity that does not fit will be left on the ground as a physical item.
func add_item_from_world(original_item: Item) -> void:
	var remaining: int = _fill_hotbar(original_item)
	if remaining != 0:
		remaining = _fill_main_inventory(original_item)
		if remaining != 0:
			original_item.respawn_item_after_quantity_change()

## Handles the logic needed for adding an item to the inventory from a given inventory item resource.
## Respects stack size. By default, any extra quantity that does not fit will be ignored and deleted.
## Can optionally specify to fill the hotbar before filling the main inventory slots.
func insert_from_inv_item(original_item: InvItemResource, delete_extra: bool = true,
							hotbar_first: bool = false) -> void:
	var remaining: int = 0

	if hotbar_first:
		remaining = _fill_hotbar(original_item)
	else:
		remaining = _fill_main_inventory(original_item)

	if remaining != 0:
		if hotbar_first:
			remaining = _fill_main_inventory(original_item)
		else:
			remaining = _fill_hotbar(original_item)

	if not delete_extra and remaining != 0:
		Item.spawn_on_ground(original_item.stats, original_item.quantity, Globals.player_node.global_position, 8, false, false, true)

## Attempts to fill the hotbar with the item passed in. Can either be an Item or an InvItemResource.
## Returns any leftover quantity that did not fit.
func _fill_hotbar(original_item: Variant) -> int:
	return _do_add_item_checks(original_item, main_inv_size, main_inv_size + hotbar_size)

## Attempts to fill the main inventory with the item passed in. Can either be an Item or an InvItemResource.
## Returns any leftover quantity that did not fit.
func _fill_main_inventory(original_item: Variant) -> int:
	return _do_add_item_checks(original_item, 0, main_inv_size)

## Wrapper function to let child functions check whether to add quantity to an item slot.
## Checks between the indices give by the start index and the stop index.
func _do_add_item_checks(original_item: Variant, start_i: int, stop_i: int) -> int:
	var inv_item: InvItemResource = InvItemResource.new(original_item.stats, original_item.quantity)

	for i: int in range(start_i, stop_i):
		if inv[i] != null and inv[i].stats.is_same_as(inv_item.stats):
			if (inv_item.quantity + inv[i].quantity) <= inv_item.stats.stack_size:
				_combine_item_count_in_occupied_slot(i, inv_item, original_item)
				return 0
			else:
				_add_what_fits_to_occupied_slot_and_continue(i, inv_item, original_item)
				inv_item = InvItemResource.new(inv_item.stats, original_item.quantity)
		if inv[i] == null:
			if inv_item.quantity <= inv_item.stats.stack_size:
				_put_entire_quantity_in_empty_slot(i, inv_item, original_item)
				return 0
			else:
				_put_what_fits_in_empty_slot_and_continue(i, inv_item, original_item)
				inv_item = InvItemResource.new(inv_item.stats, original_item.quantity)

	return original_item.quantity

## Combines the item into a slot that has space for that kind of item.
func _combine_item_count_in_occupied_slot(index: int, inv_item: InvItemResource, original_item: Variant) -> void:
	inv[index].quantity += inv_item.quantity
	if original_item is Item:
		original_item.remove_from_world()
	slot_updated.emit(index, inv[index])

## Adds what fits to an occupied slot of the same kind of item and passes the remainder to the next iteration.
func _add_what_fits_to_occupied_slot_and_continue(index: int, inv_item: InvItemResource,
													original_item: Variant) -> void:
	var amount_that_fits: int = max(0, inv_item.stats.stack_size - inv[index].quantity)
	inv[index].quantity = inv_item.stats.stack_size
	inv_item.quantity -= amount_that_fits
	original_item.quantity -= amount_that_fits
	slot_updated.emit(index, inv[index])

## Puts the entire quantity of the given item into an empty slot. This means it was less than or equal to stack size.
func _put_entire_quantity_in_empty_slot(index: int, inv_item: InvItemResource, original_item: Variant) -> void:
	inv[index] = inv_item
	if original_item is Item:
		original_item.remove_from_world()
	slot_updated.emit(index, inv[index])

## This puts what fits of an item type into an empty slot and passes the remainder to the next iteration.
func _put_what_fits_in_empty_slot_and_continue(index: int, inv_item: InvItemResource,
												original_item: Variant) -> void:
	var leftover: int = max(0, inv_item.quantity - inv_item.stats.stack_size)
	inv_item.quantity = inv_item.stats.stack_size
	inv[index] = inv_item
	original_item.quantity = leftover
	slot_updated.emit(index, inv[index])

## This removes a certain amount of an item at the target index slot. If it removes everything, it deletes it.
func remove_item(index: int, amount: int) -> void:
	var updated_item: InvItemResource = InvItemResource.new(inv[index].stats, inv[index].quantity)
	updated_item.quantity = max(0, updated_item.quantity - amount)
	inv[index] = updated_item
	if updated_item.quantity <= 0:
		inv[index] = null
	slot_updated.emit(index, inv[index])

## This updates all connected slots in order to reflect the UI properly.
func _update_all_connected_slots() -> void:
	for i: int in range(total_inv_size):
		slot_updated.emit(i, inv[i])

#region Sorting
## This auto stacks and compacts items into their stack sizes.
func activate_auto_stack() -> void:
	for i: int in range(main_inv_size):
		if inv[i] == null:
			continue
		for j: int in range(i + 1, main_inv_size):
			if inv[j] == null:
				continue
			elif inv[i].stats.is_same_as(inv[j].stats):
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
	var arr: Array[InvItemResource] = inv.slice(0, main_inv_size)
	arr.sort_custom(_rarity_sort_logic)
	for i: int in range(main_inv_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

## Called in order to start sorting by type of items in the inventory. Does not sort hotbar if present.
func activate_sort_by_type() -> void:
	var arr: Array[InvItemResource] = inv.slice(0, main_inv_size)
	arr.sort_custom(_type_sort_logic)
	for i: int in range(main_inv_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

## Called in order to start sorting by name of items in the inventory. Does not sort hotbar if present.
func activate_sort_by_name() -> void:
	var arr: Array[InvItemResource] = inv.slice(0, main_inv_size)
	arr.sort_custom(_name_sort_logic)
	for i: int in range(main_inv_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

## Implements the comparison logic for sorting by rarity.
func _rarity_sort_logic(a: InvItemResource, b: InvItemResource) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.rarity != b.stats.rarity:
		return a.stats.rarity > b.stats.rarity
	elif a.stats.item_type != b.stats.item_type:
		return a.stats.item_type > b.stats.item_type
	else:
		return a.stats.name < b.stats.name

## Implements the comparison logic for sorting by item type.
func _type_sort_logic(a: InvItemResource, b: InvItemResource) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.item_type != b.stats.item_type:
		return a.stats.item_type > b.stats.item_type
	elif a.stats.rarity != b.stats.rarity:
		return a.stats.rarity > b.stats.rarity
	elif a.stats.name != b.stats.name:
		return a.stats.name < b.stats.name
	else:
		return a.quantity > b.quantity

## Implements the comparison logic for sorting by name.
func _name_sort_logic(a: InvItemResource, b: InvItemResource) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.name != b.stats.name:
		return a.stats.name < b.stats.name
	elif a.stats.rarity != b.stats.rarity:
		return a.stats.rarity > b.stats.rarity
	else:
		return a.quantity > b.quantity
#endregion

#region Projectile Weapon Helpers
## Consumes ammo from this inventory and returns the amount back to the caller.
func get_more_ammo(max_amount_needed: int, take_from_inventory: bool,
					ammo_type: ProjWeaponResource.ProjAmmoType) -> int:
	var ammount_collected: int = 0

	for i: int in range(main_inv_size + hotbar_size): # Does not include potential trash slot
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

	for i: int in range(total_inv_size):
		if inv[i] == null and not include_null_spots:
			continue

		if inv[i] != null:
			to_print = to_print + str(inv[i])
		else:
			to_print = to_print + "NULL"

		if (i + 1) % 5 == 0 and i != total_inv_size - 1:
			to_print += "\n"
		elif i != total_inv_size - 1:
			to_print += "  |  "

	if to_print.ends_with("\n"):
		to_print = to_print.substr(0, to_print.length() - 1)
	elif to_print.ends_with("|  "):
		to_print = to_print.substr(0, to_print.length() - 3)

	print_rich(to_print + "\n[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]")
#endregion
