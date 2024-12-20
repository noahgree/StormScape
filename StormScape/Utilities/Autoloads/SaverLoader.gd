extends Node
## Global autoload that manages the saving and loading of node data to a save file when triggered.


## When called, a saved game file will be created containing the game's save data.
func save_game() -> void:
	if DebugFlags.PrintFlags.saver_loader_status_changes:
		print_rich("[color=orange]Saving...[/color]")
	var saved_game: SavedGame = SavedGame.new()

	var save_data: Array[SaveData] = []
	get_tree().call_group("has_save_logic", "_on_before_save_game")
	get_tree().call_group("has_save_logic", "_on_save_game", save_data)
	saved_game.save_data = save_data

	ResourceSaver.save(saved_game, "user://savegame1.tres")
	if DebugFlags.PrintFlags.saver_loader_status_changes:
		print_rich("--------------------------------------[color=orange][b]SAVED![/b][/color]--------------------------------------")

## When called, any existing saved save file will be loaded in.
func load_game() -> void:
	var saved_game: SavedGame = load("user://savegame1.tres") as SavedGame

	if DebugFlags.PrintFlags.saver_loader_status_changes:
		print_rich("[color=yellow]Performing 'Before Load' Functions...[/color]")

	UIDHelper.session_uid_counter = 0
	get_tree().call_group("has_save_logic", "_on_before_load_game")

	if DebugFlags.PrintFlags.saver_loader_status_changes:
		print_rich("-------------------------------------[color=yellow][b]LOADING![/b][/color]-------------------------------------")
	for item: SaveData in saved_game.save_data:
		if not (item is DynamicEntityData and item.is_player):
			if item.scene_path != "":
				var scene: PackedScene = load(item.scene_path) as PackedScene
				var loaded_node: Node = scene.instantiate()
				if loaded_node.has_method("_is_instance_on_load_game"):
					loaded_node._is_instance_on_load_game(item)
		else:
			GlobalData.player_node._is_instance_on_load_game(item)

	get_tree().call_group("has_save_logic", "_on_load_game")
	get_tree().call_group("has_save_logic", "_on_game_finished_loading")
