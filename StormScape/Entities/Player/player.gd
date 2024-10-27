extends DynamicEntity
class_name Player
## The main class for the player character.

@export var player_name: String = "Player1"

func _ready() -> void:
	SignalBus.emit_signal("PlayerReady", self)
