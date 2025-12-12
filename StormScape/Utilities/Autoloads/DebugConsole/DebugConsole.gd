extends CanvasLayer
## The console that accepts debug commands to aid in development.

@onready var console_input: LineEdit = %ConsoleInput
@onready var console_input_panel: Panel = %ConsoleInputPanel
@onready var console_output: Label = %ConsoleOutput
@onready var console_history: RichTextLabel = %ConsoleHistory
@onready var console_history_margins: MarginContainer = %ConsoleHistoryMargins

var commands: Dictionary[StringName, Callable]
var past_commands: Array[String]
var history_index: int
var showing_valid_help: bool
const MAX_PAST_COMMANDS: int = 16


func _ready() -> void:
	hide()
	console_output.hide()
	console_history.hide()
	console_input.editable = false
	add_command("help", func() -> void: print(str(commands.keys()).replace("&", "").replace("\"", "")))
	add_command("clear", func() -> void:
		past_commands.clear()
		console_history.hide()
		)

func add_command(command_name: StringName, callable: Callable) -> void:
	commands[command_name] = callable

func _call_command(command_name: StringName, args: Array[Variant]) -> void:
	var callable: Callable = commands.get(command_name, Callable())
	if callable == Callable():
		printerr("The debug command \"" + command_name + "\" did not exist.")
		MessageManager.add_msg_preset("Command Does Not Exist", MessageManager.Presets.FAIL, 4.0, true)
		return

	var target_object: Object = callable.get_object()
	if callable.is_valid():
		var max_args: int = callable.get_argument_count()
		callable.callv(args.slice(0, max_args))
		_toggle_usage()
		MessageManager.add_msg_preset(command_name + " Command Executed", MessageManager.Presets.NEUTRAL, 4.0, true)
	else:
		printerr("The debug command \"" + command_name + "\" is not valid on the object \"" + str(target_object) + "\".")
		MessageManager.add_msg_preset(command_name + " Not Valid on " + str(target_object), MessageManager.Presets.FAIL, 4.0, true)

func _add_to_command_history(string: String) -> void:
	past_commands.append(string)
	console_history.show()
	if past_commands.size() >= MAX_PAST_COMMANDS:
		past_commands.pop_front()

	_update_command_history_display()

func _update_command_history_display() -> void:
	var all_past_commands: String = ""
	for i: int in range(past_commands.size()):
		var color_str: String = "[color=Deepskyblue]" if i == history_index else ""
		all_past_commands += color_str + past_commands[i] + ("[/color]" if color_str != "" else "")
		if i <= past_commands.size() - 2:
			all_past_commands += "\n"
		i += 1
	console_history.text = all_past_commands

	if past_commands.size() > 1:
		console_history_margins.add_theme_constant_override("margin_bottom", 2)
		console_history_margins.add_theme_constant_override("margin_top", 2)
	else:
		console_history_margins.add_theme_constant_override("margin_bottom", -2)
		console_history_margins.add_theme_constant_override("margin_top", -2)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console"):
		_toggle_usage()
	elif event.is_action_pressed("esc"):
		if visible:
			_toggle_usage()
	elif console_input.has_focus() and event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_UP:
				if history_index < 0:
					history_index = past_commands.size()
				history_index = wrapi(history_index - 1, 0, min(MAX_PAST_COMMANDS, past_commands.size()))
				_show_history_and_update_text_from_past_commands()
			KEY_DOWN:
				if history_index < 0:
					history_index = past_commands.size() - 2
				history_index = wrapi(history_index + 1, 0, min(MAX_PAST_COMMANDS, past_commands.size()))
				_show_history_and_update_text_from_past_commands()
			_ when event.keycode != KEY_RIGHT and event.keycode != KEY_LEFT:
				history_index = -1
				_update_command_history_display()

func _toggle_usage() -> void:
	console_input.accept_event()
	console_input.editable = !console_input.editable
	Globals.change_focused_ui_state(console_input.editable, self)
	if console_input.editable:
		console_input.grab_focus()
		history_index = past_commands.size() - 1
		_update_command_history_display()
	else:
		console_input.release_focus()
		console_output.hide()

	visible = console_input.editable

func _parse_command(new_text: String) -> void:
	var split_elements: PackedStringArray = new_text.split(" ")
	var strings: Array = Array(split_elements)
	if showing_valid_help:
		_add_to_command_history(strings[0] + " " + console_output.text)
		return
	if not strings.is_empty() and not strings[0] == "":
		var i: int = 0
		for string: String in strings:
			if string.is_valid_int():
				strings[i] = int(string)
			elif string.is_valid_float():
				strings[i] = float(string)
			i += 1

		_add_to_command_history(new_text)
		_call_command(str(strings[0]), strings.slice(1))

func _on_console_input_text_changed(new_text: String) -> void:
	console_output.hide()
	showing_valid_help = false

	var pieces: PackedStringArray = new_text.split(" ", true)
	if not pieces.is_empty() and pieces[0] in commands:
		console_input_panel.get_theme_stylebox("panel").border_color = Color(0, 0.75, 0, 0.5)
		console_input_panel.get_theme_stylebox("panel").bg_color = Color(0.16, 0.27, 0.153, 0.502)
		if pieces.size() == 2 and pieces[1] == "help":
			console_output.text = _get_arg_list(commands[pieces[0]].get_object(), commands[pieces[0]].get_method())
			console_output.show()
			showing_valid_help = true
	else:
		console_input_panel.get_theme_stylebox("panel").border_color = Color(0, 0, 0, 0.65)
		console_input_panel.get_theme_stylebox("panel").bg_color = Color(0.0, 0.0, 0.0, 0.502)

func _get_arg_list(object: Object, method_name: String) -> String:
	if method_name == "<anonymous lambda>":
		return method_name
	var arg_list: String = ""
	var methods: Array[Dictionary] = object.get_method_list()
	var method_dict: Dictionary
	for method: Dictionary in methods:
		if method.name == method_name:
			method_dict = method
	if method_dict.is_empty():
		return "<static method>"

	var default_args: Array[Variant] = []
	default_args.resize(method_dict.args.size() - method_dict.default_args.size())
	default_args.append_array(method_dict.default_args)

	var i: int = 0
	for arg: Dictionary in method_dict.args:
		var quote_char: String = "\"" if typeof(default_args[i]) in [TYPE_STRING, TYPE_STRING_NAME] else ""
		var default_arg: String = ("=" + quote_char + str(default_args[i]) + quote_char) if default_args[i] != null else ""
		arg_list += "<" + (arg.name) + ":" + type_string(arg.type) + default_arg + ">, "
		i += 1

	return arg_list.trim_suffix(", ")


func _show_history_and_update_text_from_past_commands() -> void:
	console_input.text = ArrayHelpers.get_or_default(past_commands, history_index, console_input.text)
	_on_console_input_text_changed(console_input.text)
	_update_command_history_display()
	if not past_commands.is_empty():
		console_history.show()
		await get_tree().process_frame
		console_input.caret_column = console_input.text.length()
