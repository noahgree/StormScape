@tool
extends DynamicEntity
class_name Player
## The main class for the player character.

@onready var hotbar_ui: HotbarUI = %HotbarUI ## The UI script that manages the player hotbar.
@onready var overhead_ui: PlayerOverheadUI = %OverheadUI ## The UI script that manages the player overhead UI for things like reload bars.
@onready var interaction_prompt: Control = %InteractionPrompt ## The UI that shows when an interaction is available.

var interaction_handler: InteractionHandler = InteractionHandler.new() ## The script handling offered interactions and what to do when they are accepted.


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	super._ready()
	SignalBus.player_ready.emit(self)

	interaction_handler.prompt_ui = interaction_prompt
	SignalBus.focused_ui_closed.connect(interaction_handler.recheck_queue)

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact") and not Globals.focused_ui_is_open:
		interaction_handler.accept_interaction()
