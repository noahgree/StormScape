extends Node

@onready var world_root: WorldRoot = get_parent().get_node("Game/WorldRoot")

var player_node: Player = null


func _ready() -> void:
	player_node = await SignalBus.PlayerReady

func save_game() -> void:
	print_rich("[color=orange]SAVING[/color]")
	var saved_game: SavedGame = SavedGame.new()
	
	var save_data: Array[SaveData] = []
	get_tree().call_group("has_save_logic", "_on_save_game", save_data)
	saved_game.save_data = save_data
	
	ResourceSaver.save(saved_game, "user://savegame1.tres")

func load_game() -> void:
	print_rich("[color=yellow]LOADING[/color]")
	var saved_game: SavedGame = load("user://savegame1.tres") as SavedGame
	
	get_tree().call_group("has_save_logic", "_on_before_load_game")
	
	for item in saved_game.save_data:
		if item is PlayerData:
			player_node._on_load_game_player(item)
			continue
		var scene = load(item.scene_path) as PackedScene
		var loaded_node = scene.instantiate()
		
		if loaded_node.has_method("_on_load_game_instance"):
			loaded_node._on_load_game(item)
	
	get_tree().call_group("has_save_logic", "_on_load_game")
