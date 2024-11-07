@icon("res://Utilities/Debug/EditorIcons/item_receiver_component.svg")
extends Inventory
class_name ItemReceiverComponent
## When attached to an entity, this gives it the ability to pick up items when overlapping with this collision box.
##
## For all intensive purposes (and as you can see based on the inheritance), this is an inventory.

@onready var player_communicator: Node = get_node_or_null("PlayerInvCommunicator")

var items_in_range: Array[Item] = []


#region Save & Load
func _on_save_game(_save_data: Array[SaveData]) -> void:
	pass

func _on_before_load_game() -> void:
	inv_to_load_from_save = []
	items_in_range = []

func _on_load_game() -> void:
	print(inv_to_load_from_save)
	fill_inventory_without_checks(inv_to_load_from_save)
#endregion

func add_to_in_range_queue(item: Item) -> void:
	items_in_range.append(item)
	_update_player_communicator()

func remove_from_in_range_queue(item: Item) -> void:
	var index: int = items_in_range.find(item)
	if index != -1: items_in_range.remove_at(index)
	_update_player_communicator()

func _update_player_communicator() -> void:
	if player_communicator:
		if items_in_range.is_empty():
			player_communicator._hide_player_interact_hud()
		else:
			player_communicator._show_player_interact_hud(items_in_range)

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact"):
		_pickup_item()

func _pickup_item() -> void:
	if not items_in_range.is_empty():
		add_item_from_world(items_in_range.pop_back())
