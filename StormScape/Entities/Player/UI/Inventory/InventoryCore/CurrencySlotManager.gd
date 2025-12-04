extends MarginContainer
class_name CurrencySlotManager
## Handles the storing and displaying of currency items for the player inside the player's inv UI.

@export var type_order: Array[Globals.CurrencyType] ## Defines ordering of currency slots by type.

@onready var currency_slots_grid: HBoxContainer = %CurrencySlotsGrid ## Reference to the grid of slots.

var starting_index: int ## The index of the first currency slot in the player's slot indices.


## Sets up the currency slots with their needed data and syncs itself to the PlayerInvResource.
func setup_slots(inventory_ui: PlayerInvUI) -> void:
	inventory_ui.synced_inv_src_node.inv.currency_slot_manager = self

	var i: int = 0
	for slot: CurrencySlot in currency_slots_grid.get_children():
		inventory_ui.assign_preexitsing_slot(slot)
		if i == 0:
			starting_index = slot.index
		i += 1
