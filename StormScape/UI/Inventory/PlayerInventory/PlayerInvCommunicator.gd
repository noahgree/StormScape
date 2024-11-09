extends Node
## Used as a child of an item receiver to communicate with the player's item interaction HUD.
##
## Created as a separate, lightweight script to avoid having this functionality on every item receiver node.

@export var item_interact_hud: ItemInteractionHUD ## The player's item interaction hud to connect to.


## Shows the interact hud for the most recent item in range.
func _show_player_interact_hud(items_in_range: Array[Item]) -> void:
	if not items_in_range.is_empty(): item_interact_hud.show_hud(items_in_range[items_in_range.size() - 1])

## Hides the player interact hud.
func _hide_player_interact_hud() -> void:
	item_interact_hud.hide_hud()
