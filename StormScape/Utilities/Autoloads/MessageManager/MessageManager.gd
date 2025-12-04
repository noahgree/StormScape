extends CanvasLayer
## Autoload that handles creating and displaying HUD messages for general feedback and notifications.

enum Presets { NEUTRAL, SUCCESS, FAIL, CRITICAL_SUCCESS, CRITICAL_FAIL } ## The preset identifiers for messages.

@export var max_displayed: int = 6 ## How many messages can be displayed at once.
@export var max_queue_size: int = 20 ## How many messages can be backed up in the queue.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var default_display_time: float = 5.0 ## By default, this is how long each message will show.

@onready var message_manager: MarginContainer = %MessageManager ## The top-level control for this scene.
@onready var message_stack: VBoxContainer = %MessageStack ## The VBox holding the messages.

var hud_message_scn: PackedScene = load("uid://emm1c404rb6y") ## The HUDMessage scene to instantiate.
var presets: Dictionary[Presets, Dictionary] = { ## Message styling presets.
	Presets.NEUTRAL : {
		"text_color" : Color.WHITE,
		"icon" : load("uid://cjfmlylpqc505"),
		"icon_color" : Color.WHITE
	},
	Presets.SUCCESS : {
		"text_color" : Color.WHITE,
		"icon" : load("uid://cjfmlylpqc505"),
		"icon_color" : Globals.ui_colors.ui_success
	},
	Presets.FAIL : {
		"text_color" : Color.WHITE,
		"icon" : load("uid://cjfmlylpqc505"),
		"icon_color" : Globals.ui_colors.ui_fail
	},
	Presets.CRITICAL_SUCCESS : {
		"text_color" : Globals.ui_colors.ui_success,
		"icon" : load("uid://cjfmlylpqc505"),
		"icon_color" : Globals.ui_colors.ui_glow_success
	},
	Presets.CRITICAL_FAIL : {
		"text_color" : Globals.ui_colors.ui_fail,
		"icon" : load("uid://cjfmlylpqc505"),
		"icon_color" : Globals.ui_colors.ui_glow_fail
	}
}
var msg_queue: Array[Dictionary] ## The queue for messages that are waiting to be displayed.
var active_msgs: Dictionary[StringName, bool] ## The active messages in the stack or the queue. True as the value means they are displayed, false as the value means they are in the queue.


func _ready() -> void:
	SignalBus.ui_focus_opened.connect(_move_for_inventory.bind(true))
	SignalBus.ui_focus_closed.connect(_move_for_inventory.bind(false))

func _move_for_inventory(node: Node, shown: bool) -> void:
	if node is PlayerInvUI:
		if shown:
			message_manager.set_anchor_and_offset(SIDE_TOP, 1.0, 0)
			message_manager.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0)
			message_manager.add_theme_constant_override("margin_bottom", 4)
		else:
			message_manager.set_anchor_and_offset(SIDE_TOP, 0.5, 0)
			message_manager.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 0)
			message_manager.remove_theme_constant_override("margin_bottom")

## Adds a message to the stack (or queue if too many are already showing). Filters repeats.
func add_msg(text: String, text_color: Color = Globals.ui_colors.ui_light_tan,
				icon: Texture2D = load("uid://cjfmlylpqc505"), icon_color: Color = Color.WHITE,
				display_time: float = default_display_time) -> void:
	if message_stack.get_child_count() >= max_displayed:
		if msg_queue.size() >= max_queue_size:
			return
		elif active_msgs.has(StringName(text)):
			return
		msg_queue.append({
			"text" : text, "text_color" : text_color,
			"icon" : icon, "icon_color" : icon_color,
			"display_time" : display_time
			})
		active_msgs[StringName(text)] = false
	else:
		if not active_msgs.get(StringName(text), false):
			var hud_message: HUDMessage = hud_message_scn.instantiate()
			message_stack.add_child(hud_message)
			hud_message.set_details(text, text_color, icon, icon_color, display_time)
			active_msgs[StringName(text)] = true

## Adds a message from a preset. Still obeys queuing and filtering repeats.
func add_msg_preset(text: String, preset: Presets, display_time: float = default_display_time) -> void:
	add_msg(text, presets[preset]["text_color"], presets[preset]["icon"], presets[preset]["icon_color"], display_time)


func _on_message_stack_child_exiting_tree(msg: HUDMessage) -> void:
	# Erase the message from the active message dict that just got freed
	active_msgs.erase(msg.text_label.text)

	# If we have a queue to use, send the front message to the adder function
	if msg_queue.size() > 0:
		var msg_details: Dictionary[Variant, Variant] = msg_queue.pop_front()
		add_msg.call_deferred(msg_details.text, msg_details.text_color, msg_details.icon, msg_details.icon_color, msg_details.get("display_time", default_display_time))
