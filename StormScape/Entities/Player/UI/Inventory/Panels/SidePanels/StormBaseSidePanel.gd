extends SidePanel
## Subclass specifically for the storm base side panel.

@onready var fuel_slot: Slot = %FuelSlot ## The fuel slot.
@onready var base_upgrade_slots: GridContainer = %BaseUpgradeSlots ## The grid container holding the upgrade slots.


## Override of the setup function for this specific side panel.
func setup() -> void:
	assign_preexitsing_slot(fuel_slot)

	for slot: Slot in base_upgrade_slots.get_children():
		assign_preexitsing_slot(slot)
