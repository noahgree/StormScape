extends DynamicEntity
class_name Player
## The main class for the player character. Mostly handles player-specific save and load logic.

@export var player_name: String = "Player1" ## The string name of the player.


func _ready() -> void:
	super._ready()
	SignalBus.player_ready.emit(self)
