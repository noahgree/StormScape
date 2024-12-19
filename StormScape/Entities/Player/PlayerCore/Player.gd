extends DynamicEntity
class_name Player
## The main class for the player character. Mostly handles player-specific save and load logic.


func _ready() -> void:
	super._ready()
	SignalBus.player_ready.emit(self)
