@tool
extends DynamicEntity
class_name Player
## The main class for the player character.

@onready var hotbar_ui: HotbarUI = %HotbarUI ## The UI script that manages the player hotbar.
@onready var overhead_ui: PlayerOverheadUI = %OverheadUI ## The UI script that manages the player overhead UI for things like reload bars.

var interaction_handler: InteractionHandler = InteractionHandler.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	super._ready()
	SignalBus.player_ready.emit(self)

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact") and not Globals.focused_ui_is_open:
		interaction_handler.on_interaction_accepted()
