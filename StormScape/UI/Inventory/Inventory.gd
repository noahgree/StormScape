extends Node
class_name Inventory
## The main superclass for any inventory controller.

signal slot_updated(index: int, item: InventoryItem)

@export var inv_size: int = 32
@export var inv_populator: InventoryPopulator
@export var ui: InventoryUI

var inv: Array[InventoryItem] = []


func _ready() -> void:
	inv.resize(inv_size)
	inv_populator.connect_inventory(self)
	ui.connect_inventory(self)

func add_item_from_world(item: Item) -> bool:
	var inv_item: InventoryItem = InventoryItem.new(item.stats, item.quantity)
	for i in range(inv_size):
		if inv[i] != null and inv[i].stats.is_same_as(inv_item.stats):
			if (inv_item.quantity + inv[i].quantity) <= inv_item.stats.stack_size:
				_combine_item_count_in_occupied_slot(i, item, inv_item)
				return true
			else:
				_add_what_fits_to_occupied_slot_and_continue(i, item, inv_item)
		if inv[i] == null:
			if inv_item.quantity <= inv_item.stats.stack_size:
				_put_entire_quantity_in_empty_slot(i, item, inv_item)
				return true
			else:
				_put_what_fits_in_empty_slot_and_continue(i, item, inv_item)
				inv_item = InventoryItem.new(item.stats, item.quantity)
	return false

func _combine_item_count_in_occupied_slot(index, item, inv_item) -> void:
	inv[index].quantity += inv_item.quantity
	item.queue_free()
	slot_updated.emit(index, inv[index])

func _add_what_fits_to_occupied_slot_and_continue(index, item, inv_item) -> void:
	var amount_that_fits: int = max(0, inv_item.stats.stack_size - inv[index].quantity)
	inv[index].quantity = inv_item.stats.stack_size
	inv_item.quantity -= amount_that_fits
	item.quantity -= amount_that_fits
	slot_updated.emit(index, inv[index])

func _put_entire_quantity_in_empty_slot(index, item, inv_item) -> void:
	inv[index] = inv_item
	item.queue_free()
	slot_updated.emit(index, inv[index])

func _put_what_fits_in_empty_slot_and_continue(index, item, inv_item) -> void:
	var leftover: int = max(0, inv_item.quantity - inv_item.stats.stack_size)
	inv_item.quantity = inv_item.stats.stack_size
	inv[index] = inv_item
	item.quantity = leftover
	slot_updated.emit(index, inv[index])

func remove_item() -> void:
	pass

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
