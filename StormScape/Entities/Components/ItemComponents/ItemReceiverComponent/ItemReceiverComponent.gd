@tool
@icon("res://Utilities/Debug/EditorIcons/item_receiver_component.svg")
extends Inventory
class_name ItemReceiverComponent
## When attached to an entity, this gives it the ability to pick up items when overlapping with this collision box.
##
## For all intensive purposes (and as you can see based on the inheritance), this is an inventory.

@export var pickup_range: int = 12: ## How big the collision shape is in px that is detected by items to enable pickup.
	set(new_range):
		pickup_range = new_range
		$CollisionShape2D.shape.radius = pickup_range
@export var item_interact_hud: ItemInteractionHUD ## The player's item interaction hud to connect to.

var items_in_range: Array[Item] = [] ## The items in range of being picked up.


#region Save & Load
func _on_save_game(_save_data: Array[SaveData]) -> void:
	# Weapons need to have their mods reloaded into the new duplicated stats instance after a game is loaded, so before we save the game we mark all weapon resources as needing to have this done. Because the weapons themselves get freed then reinstantiated, the inventory component has to call this logic from here (and not do it in each weapon, because they get freed on load).
	for item: InvItemResource in inv:
		if item != null and item.stats is WeaponResource:
			item.stats.weapon_mods_need_to_be_readded_after_save = true

func _on_before_load_game() -> void:
	inv_to_load_from_save = []
	items_in_range = []

func _on_load_game() -> void:
	fill_inventory(inv_to_load_from_save)
#endregion

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	super._ready()
	collision_layer = 0b10000000

## Adds an item to the in range queue.
func add_to_in_range_queue(item: Item) -> void:
	items_in_range.append(item)
	_update_player_item_interact_hud()

## Removes an item from the in range queue.
func remove_from_in_range_queue(item: Item) -> void:
	var index: int = items_in_range.find(item)
	if index != -1:
		items_in_range.remove_at(index)
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
		item_interact_hud.show_hud(items_in_range[items_in_range.size() - 1])

## Hides the player interact hud.
func _hide_player_interact_hud() -> void:
	item_interact_hud.hide_hud()

func _unhandled_key_input(_event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if Input.is_action_just_pressed("interact") and not Globals.focused_ui_is_open:
		_pickup_item_from_queue()

## Attempts to pick up the first item in the items in range queue. The method it calls will drop what doesn't
## fit back on the ground with the appropriate updated quantity.
func _pickup_item_from_queue() -> void:
	if not items_in_range.is_empty():
		if items_in_range[items_in_range.size() - 1].can_be_picked_up_at_all:
			add_item_from_world(items_in_range.pop_back())
