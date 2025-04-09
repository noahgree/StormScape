extends CanvasLayer
## The console that accepts debug commands to aid in development.

@onready var console_input: LineEdit = %ConsoleInput
@onready var console_input_panel: Panel = %ConsoleInputPanel

var commands: Dictionary[StringName, Callable]

func _ready() -> void:
	console_input.hide()
	console_input.editable = false
	add_command("help", func() -> void: print(commands.keys()))

func add_command(command_name: StringName, callable: Callable) -> void:
	commands[command_name] = callable

func _call_command(command_name: StringName, args: Array[Variant]) -> void:
	var callable: Callable = commands.get(command_name, Callable())
	if callable == Callable():
		printerr("The debug command \"" + command_name + "\" did not exist.")
		return

	var target_object: Object = callable.get_object()
	if callable.is_valid():
		var max_args: int = callable.get_argument_count()
		callable.callv(args.slice(0, max_args))
		_toggle_usage()
	else:
		printerr("The debug command \"" + command_name + "\" is not valid on the object \"" + str(target_object) + "\".")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console"):
		_toggle_usage()
	elif event.is_action_pressed("esc"):
		if console_input.visible:
			_toggle_usage()

func _toggle_usage() -> void:
	console_input.accept_event()
	console_input.editable = !console_input.editable
	Globals.change_focused_ui_state(console_input.editable)
	if console_input.editable:
		console_input.grab_focus()
	else:
		console_input.release_focus()

	console_input.visible = console_input.editable

func _on_console_input_text_submitted(new_text: String) -> void:
	var split_elements: PackedStringArray = new_text.split(" ")
	var strings: Array = Array(split_elements)
	if not strings.is_empty():
		var i: int = 0
		for string: String in strings:
			if string.is_valid_int():
				strings[i] = int(string)
			elif string.is_valid_float():
				strings[i] = float(string)
			i += 1

		_call_command(strings[0], strings.slice(1))

func _on_console_input_text_changed(new_text: String) -> void:
	var pieces: PackedStringArray = new_text.split(" ", true)
	if not pieces.is_empty() and pieces[0] in commands:
		console_input_panel.get_theme_stylebox("panel").border_color = Color(0, 0.75, 0, 0.5)
		if pieces.size() == 2 and pieces[1] == "help":
			console_input.text += " (" + _get_arg_list(commands[pieces[0]].get_object(), commands[pieces[0]].get_method()) + ")"
			console_input.caret_column = console_input.text.length()
	else:
		console_input_panel.get_theme_stylebox("panel").border_color = Color(0, 0, 0, 0.65)

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
		return "static method, args hidden"

	for arg: Dictionary in method_dict.args:
		arg_list += (arg.name) + ", "

	return arg_list.trim_suffix(", ")
