extends Area2D
class_name Inventory
## The main superclass for any inventory controller.

signal slot_updated(index: int, item: InventoryItem)

@export var is_player_inv: bool = false ## Whether this is the player's inventory or not. Needed for hotbar logic.
@export var inv_size: int = 32 ## The total number of slots in the inventory, including the hotbar slots.
@export var hotbar_size: int = 0 ## The number of slots out of the inv_size that are in the hotbar. Only affects the player inv.
@export var inv_populator: InventoryPopulator
@export var ui: InventoryUI

var inv: Array[InventoryItem] = []


func _ready() -> void:
	if not is_player_inv:
		hotbar_size = 0
	inv.resize(inv_size)
	inv_populator.connect_inventory(self)
	ui.connect_inventory(self)

func add_item_from_world(item: Item) -> bool:
	var inv_item: InventoryItem = InventoryItem.new(item.stats, item.quantity)
	for i in range(hotbar_size):
		var result: String = _do_add_item_checks(i + (inv_size - hotbar_size), item, inv_item)
		if result == "done":
			return true
		elif result == "new inv item created":
			inv_item = InventoryItem.new(item.stats, item.quantity)
	for i in range(inv_size - hotbar_size):
		var result: String = _do_add_item_checks(i, item, inv_item)
		if result == "done":
			return true
		elif result == "new inv item created":
			inv_item = InventoryItem.new(item.stats, item.quantity)
	return false

func _do_add_item_checks(index: int, item: Item, inv_item: InventoryItem) -> String:
	if inv[index] != null and inv[index].stats.is_same_as(inv_item.stats):
		if (inv_item.quantity + inv[index].quantity) <= inv_item.stats.stack_size:
			_combine_item_count_in_occupied_slot(index, item, inv_item)
			return "done"
		else:
			_add_what_fits_to_occupied_slot_and_continue(index, item, inv_item)
	if inv[index] == null:
		if inv_item.quantity <= inv_item.stats.stack_size:
			_put_entire_quantity_in_empty_slot(index, item, inv_item)
			return "done"
		else:
			_put_what_fits_in_empty_slot_and_continue(index, item, inv_item)
			return "new inv item created"
	return ""

func _combine_item_count_in_occupied_slot(index: int, item: Item, inv_item: InventoryItem) -> void:
	inv[index].quantity += inv_item.quantity
	item.queue_free()
	slot_updated.emit(index, inv[index])

func _add_what_fits_to_occupied_slot_and_continue(index: int, item: Item, inv_item: InventoryItem) -> void:
	var amount_that_fits: int = max(0, inv_item.stats.stack_size - inv[index].quantity)
	inv[index].quantity = inv_item.stats.stack_size
	inv_item.quantity -= amount_that_fits
	item.quantity -= amount_that_fits
	slot_updated.emit(index, inv[index])

func _put_entire_quantity_in_empty_slot(index: int, item: Item, inv_item: InventoryItem) -> void:
	inv[index] = inv_item
	item.queue_free()
	slot_updated.emit(index, inv[index])

func _put_what_fits_in_empty_slot_and_continue(index: int, item: Item, inv_item: InventoryItem) -> void:
	var leftover: int = max(0, inv_item.quantity - inv_item.stats.stack_size)
	inv_item.quantity = inv_item.stats.stack_size
	inv[index] = inv_item
	item.quantity = leftover
	slot_updated.emit(index, inv[index])

func remove_item() -> void:
	pass

func _update_all_connected_slots() -> void:
	for i in range(inv_size):
		slot_updated.emit(i, inv[i])

#region Sorting
func activate_auto_stack() -> void:
	for i in range(inv_size - hotbar_size):
		if inv[i] == null:
			continue
		for j in range(i + 1, inv_size - hotbar_size):
			if inv[j] == null:
				continue
			if inv[i].stats.is_same_as(inv[j].stats):
				var total_quantity = inv[i].quantity + inv[j].quantity
				if total_quantity <= inv[i].stats.stack_size:
					inv[i].quantity = total_quantity
					inv[j] = null
				else:
					inv[i].quantity = inv[i].stats.stack_size
					inv[j].quantity = total_quantity - inv[i].stats.stack_size

	_update_all_connected_slots()

func activate_sort_by_rarity() -> void:
	var arr = inv.slice(0, inv_size - hotbar_size)
	arr.sort_custom(_rarity_sort_logic)
	for i in range(inv_size - hotbar_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

func activate_sort_by_count() -> void:
	var arr = inv.slice(0, inv_size - hotbar_size)
	arr.sort_custom(_count_sort_logic)
	for i in range(inv_size - hotbar_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

func activate_sort_by_name() -> void:
	var arr = inv.slice(0, inv_size - hotbar_size)
	arr.sort_custom(_name_sort_logic)
	for i in range(inv_size - hotbar_size):
		inv[i] = arr[i]
	_update_all_connected_slots()

func _rarity_sort_logic(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.rarity != b.stats.rarity:
		return a.stats.rarity > b.stats.rarity
	else:
		return a.stats.name < b.stats.name

func _count_sort_logic(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.quantity != b.quantity:
		return a.quantity > b.quantity
	else:
		return a.stats.name < b.stats.name

func _name_sort_logic(a: InventoryItem, b: InventoryItem) -> bool:
	if a == null and b == null: return false
	if a == null: return false
	if b == null: return true

	if a.stats.name != b.stats.name:
		return a.stats.name < b.stats.name
	else:
		return a.quantity < b.quantity
#endregion

func print_inv(include_null_spots: bool = false) -> void:
	var to_print: String = "[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]\n"
	for i in range(inv_size):
		if inv[i] == null and not include_null_spots:
			continue
		to_print = to_print + str(inv[i])
		if (i + 1) % 5 == 0 and i != inv_size - 1: to_print += "\n"
		elif i != inv_size - 1: to_print += "  |  "
	if to_print.ends_with("\n"): to_print = to_print.substr(0, to_print.length() - 1)
	elif to_print.ends_with("|  "): to_print = to_print.substr(0, to_print.length() - 3)
	print_rich(to_print + "\n[b]-----------------------------------------------------------------------------------------------------------------------------------[/b]")
