extends Node
class_name Inventory
## The main superclass for any inventory controller.

signal slot_updated(index: int, item: InventoryItem)

@export var inv_size: int = 32
@export var ui: InventoryPopulator

var inv: Array[InventoryItem] = []


func _ready() -> void:
	inv.resize(inv_size)
	ui.connect_inventory(self)

func add_item(item: Item) -> bool:
	var inv_item: InventoryItem = InventoryItem.new(item.stats, item.quantity)
	for i in range(inv_size):
		if inv[i] != null and inv[i].stats.is_same_as(inv_item.stats):
			if (inv_item.quantity + inv[i].quantity) <= inv_item.stats.stack_size:
				inv[i].quantity += inv_item.quantity
				item.queue_free()
				slot_updated.emit(i, inv[i])
				return true
			else:
				var amount_that_fits: int = max(0, inv_item.stats.stack_size - inv[i].quantity)
				inv[i].quantity = inv_item.stats.stack_size
				inv_item.quantity -= amount_that_fits
				item.quantity -= amount_that_fits
				slot_updated.emit(i, inv[i])
				continue
		if inv[i] == null:
			if inv_item.quantity <= inv_item.stats.stack_size:
				inv[i] = inv_item
				item.queue_free()
				slot_updated.emit(i, inv[i])
				return true
			else:
				var leftover: int = max(0, inv_item.quantity - inv_item.stats.stack_size)
				inv_item.quantity = inv_item.stats.stack_size
				inv[i] = inv_item
				item.quantity = leftover
				inv_item = InventoryItem.new(item.stats, item.quantity)
				slot_updated.emit(i, inv[i])

	return false

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
