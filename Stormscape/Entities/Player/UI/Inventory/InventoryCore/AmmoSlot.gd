@icon("res://Utilities/Debug/EditorIcons/slot.svg")
extends Slot
class_name AmmoSlot
## A child class of Slot that changes the conditions for which data can be dropped.


## Determines if the slot we are hovering over during a drag can accept drag data on mouse release.
func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	CursorManager.update_tooltip("Invalid!", Globals.ui_colors.ui_glow_strong_fail)
	return false

func _get_drag_data(_at_position: Vector2) -> Variant:
	return null

func _gui_input(_event: InputEvent) -> void:
	return
