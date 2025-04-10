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

	DebugConsole.add_command("give", inv.grant_from_item_id)
	DebugConsole.add_command("remove", inv.remove_item)
	DebugConsole.add_command("print_inv", inv.print_inv)
	DebugConsole.add_command("effect", effect_receiver.apply_effect_by_id)
	DebugConsole.add_command("remove_effect", effect_receiver.remove_effect_by_id)
	DebugConsole.add_command("tp", teleport_relative)
	DebugConsole.add_command("tp_set", teleport)
	DebugConsole.add_command("hp", health_component.change_hp_by_amount)
	DebugConsole.add_command("stamina", stamina_component.change_stamina_by_amount)
	DebugConsole.add_command("hunger_bars", stamina_component.change_hunger_bars_by_amount)
	DebugConsole.add_command("wpn_mod", hands.add_mod_to_weapon_by_id)
	DebugConsole.add_command("mod", stats.add_mod_from_scratch)
	DebugConsole.add_command("remove_mod", stats.remove_mod)
	DebugConsole.add_command("coords", func() -> void: print(global_position))

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("interact") and not Globals.focused_ui_is_open:
		interaction_handler.accept_interaction()

## Moves the player by the given x and y amounts relative to the current global position.
func teleport_relative(x: int, y: int) -> void:
	global_position += Vector2(x, y)

## Moves the player to the given x and y coordinate.
func teleport(x: int, y: int) -> void:
	global_position = Vector2(x, y)
