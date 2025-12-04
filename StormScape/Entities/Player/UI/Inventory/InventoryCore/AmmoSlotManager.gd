extends MarginContainer
class_name AmmoSlotManager
## Handles the storing and displaying of ammo for the player inside the player's inv UI.

@export var type_order: Array[ProjWeaponResource.ProjAmmoType] ## Defines ordering of ammo slots by type.

@onready var ammo_slots_grid: HBoxContainer = %AmmoSlotsGrid ## Reference to the grid of slots.

var starting_index: int ## The index of the first ammo slot in the player's slot indices.


## Sets up the ammo slots with their needed data and syncs itself to the PlayerInvResource.
func setup_slots(inventory_ui: PlayerInvUI) -> void:
	inventory_ui.synced_inv_src_node.inv.ammo_slot_manager = self

	var i: int = 0
	for slot: AmmoSlot in ammo_slots_grid.get_children():
		inventory_ui.assign_preexitsing_slot(slot)
		if i == 0:
			starting_index = slot.index
		i += 1
