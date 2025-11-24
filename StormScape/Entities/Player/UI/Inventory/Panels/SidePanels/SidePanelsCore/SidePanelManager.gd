extends Control
class_name SidePanelManager
## Handles the connections and setup of side panels in the player's inventory.

@onready var player_inv_ui: PlayerInvUI = get_parent() ## A reference to the parent player inv ui.

var active_panel: SidePanel ## Populated with whatever the active panel is, if it exists and is open.


func _ready() -> void:
	SignalBus.side_panel_open_request.connect(_setup)

## Deletes the active side panel.
func delete(new_value: bool) -> void:
	if new_value and active_panel:
		active_panel.queue_free()

## Instatiates and adds the incoming side panel given the packed scene and its source node.
func _setup(new_panel: PackedScene, side_panel_src: Node) -> void:
	if active_panel:
		active_panel.queue_free()
		active_panel = null

	active_panel = new_panel.instantiate()
	add_child(active_panel)

	_link_potential_inv(side_panel_src)

	player_inv_ui.open_with_side_panel()

## Links the inventory in the side panel to its source node, given that it has an inventory slot manager.
func _link_potential_inv(side_panel_src: Node) -> void:
	if not active_panel.inv_slot_mgr:
		return

	active_panel.inv_slot_mgr.link_new_inventory_source_node(side_panel_src)
	active_panel.title_node.text = side_panel_src.inv.title
