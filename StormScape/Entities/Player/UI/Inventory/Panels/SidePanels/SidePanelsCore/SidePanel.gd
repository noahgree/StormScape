extends InvSlotManager
class_name SidePanel
## The top level class for packed scenes that become side panels in the player's inventory screen.
##
## Inherits InvSlotManager for convienience when adding inventories to these panels.

@export var title_node: Label ## The title label of this side panel. Can be null.


## Intended to be overwridden by subclasses if they have specific setup logic. Called after instantiation.
func setup() -> void:
	pass
