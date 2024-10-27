extends Node

var player_node: Player = null


func _ready() -> void:
	player_node = await SignalBus.PlayerReady

func save_game() -> void:
	var saved_game: SavedGame = SavedGame.new()
	
	saved_game.player_position = player_node.global_position
	
	var save_data: Array[SaveData] = []
	get_tree().call_group("has_save_data", "_on_save_game", save_data)
	saved_game.save_data = save_data
	
	
	ResourceSaver.save(saved_game, "user://savegame1.tres")

func load_game() -> void:
	var saved_game: SavedGame = load("user://savegame1.tres") as SavedGame
	
	player_node.global_position = saved_game.player_position

	#get_tree().call_group("has_save_data", "_on_before_load_game")
	#
	#get_tree().call_group("has_save_data", "_on_load_game", saved_game)
