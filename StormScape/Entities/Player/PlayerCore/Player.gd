extends DynamicEntity
class_name Player
## The main class for the player character. Mostly handles player-specific save and load logic.

@onready var hotbar_ui: HotbarUI = %HotbarUI ## The UI script that manages the player hotbar.
@onready var overhead_ui: PlayerOverheadUI = %OverheadUI ## The UI script that manages the player overhead UI for things like reload bars.


func _ready() -> void:
	super._ready()
	SignalBus.player_ready.emit(self)
