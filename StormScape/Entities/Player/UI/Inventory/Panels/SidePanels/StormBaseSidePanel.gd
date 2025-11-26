extends SidePanel

@onready var fuel_slot: Slot = %FuelSlot ## The fuel slot.


func setup() -> void:
	assign_preexitsing_slot(fuel_slot)
