extends Node

@export var item_interact_hud: ItemInteractionHUD

func _show_player_interact_hud(items_in_range: Array[Item]) -> void:
	if not items_in_range.is_empty(): item_interact_hud.show_hud(items_in_range[items_in_range.size() - 1])

func _hide_player_interact_hud() -> void:
	item_interact_hud.hide_hud()
