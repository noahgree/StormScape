@tool
extends StaticEntity
class_name PhysicalInventory
## An interactable inventory in the game world.

@export var panel_scene: PackedScene

@onready var interaction_area: InteractionArea = %InteractionArea ## The area handling player interactions.


func _ready() -> void:
	if not Engine.is_editor_hint():
		interaction_area.set_accept_callable(_accept_callable)
		super()

## The function to call when the interaction offer of this inventory is accepted.
func _accept_callable() -> void:
	SignalBus.side_panel_open_request.emit(panel_scene, self)
	sprite.frame = 1 # Display in an open state
