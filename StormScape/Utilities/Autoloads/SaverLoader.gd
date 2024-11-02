extends Node


func save_game() -> void:
	if DebugFlags.PrintFlags.saver_loader_status_changes: print_rich("[color=orange]Saving...[/color]")
	var saved_game: SavedGame = SavedGame.new()

	var save_data: Array[SaveData] = []
	get_tree().call_group("has_save_logic", "_on_save_game", save_data)
	saved_game.save_data = save_data

	ResourceSaver.save(saved_game, "user://savegame1.tres")
	if DebugFlags.PrintFlags.saver_loader_status_changes: print_rich("--------------------------------------[color=orange][b]SAVED![/b][/color]--------------------------------------")

func load_game() -> void:
	var saved_game: SavedGame = load("user://savegame1.tres") as SavedGame
	if DebugFlags.PrintFlags.saver_loader_status_changes: print_rich("[color=yellow]Performing 'Before Load' Functions...[/color]")
	get_tree().call_group("has_save_logic", "_on_before_load_game")
	if DebugFlags.PrintFlags.saver_loader_status_changes: print_rich("-------------------------------------[color=yellow][b]LOADING![/b][/color]-------------------------------------")

	for item in saved_game.save_data:
		if item is PlayerData:
			GlobalData.player_node._on_load_game_player(item)
			continue
		var scene = load(item.scene_path) as PackedScene
		var loaded_node = scene.instantiate()

		if loaded_node.has_method("_on_load_game_instance"):
			loaded_node._on_load_game(item)

	get_tree().call_group("has_save_logic", "_on_load_game")
