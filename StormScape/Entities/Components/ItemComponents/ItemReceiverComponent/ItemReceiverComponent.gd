@icon("res://Utilities/Debug/EditorIcons/item_receiver_component.svg")
extends Area2D
class_name ItemReceiverComponent
## When attached to an entity, this gives it the ability to pick up items when overlapping with this collision box.

@export var pickup_range: int = 12: ## How big the collision shape is in px that is detected by items to enable pickup.
	set(new_range):
		pickup_range = new_range
		if collision_shape:
			collision_shape.shape.radius = pickup_range
@export var item_interact_hud: ItemInteractionHUD ## The player's item interaction hud to connect to.

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var items_in_range: Array[Item] = [] ## The items in range of being picked up.
var synced_inv: InventoryResource ## The inventory to add to.


#region Save & Load
func _on_before_load_game() -> void:
	items_in_range = []
#endregion

func _ready() -> void:
	if not get_parent().is_node_ready():
		await get_parent().ready
	synced_inv = get_parent().inv

	collision_layer = 0b10000000

## Adds an item to the in range queue.
func add_to_in_range_queue(item: Item) -> void:
	items_in_range.append(item)
	_update_player_item_interact_hud()

## Removes an item from the in range queue.
func remove_from_in_range_queue(item: Item) -> void:
	items_in_range.erase(item)
	_update_player_item_interact_hud()

## When used on a player, this method notifies the connected HUD of item pickup item changes.
func _update_player_item_interact_hud() -> void:
	if not item_interact_hud:
		return

	if items_in_range.is_empty():
		_hide_player_interact_hud()
	else:
		_show_player_interact_hud()

## Shows the interact hud for the most recent item in range.
func _show_player_interact_hud() -> void:
	if not items_in_range.is_empty():
		item_interact_hud.show_hud(items_in_range.back())

## Hides the player interact hud.
func _hide_player_interact_hud() -> void:
	item_interact_hud.hide_hud()

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact") and not Globals.focused_ui_is_open:
		_pickup_item_from_queue()

## Attempts to pick up the first item in the items in range queue. The method it calls will drop what doesn't
## fit back on the ground with the appropriate updated quantity.
func _pickup_item_from_queue() -> void:
	if not items_in_range.is_empty():
		if items_in_range[items_in_range.size() - 1].can_be_picked_up_at_all:
			synced_inv.add_item_from_world(items_in_range.pop_back())
			item_interact_hud.accept_event() # So if we actually pick something up we don't keep triggering interaction events
