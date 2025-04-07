@tool
extends Control

@export var default_color: Color
@export var hover_color: Color

@onready var next_screen_btn: TextureButton = $HBoxContainer/NextScreenBtn
@onready var same_screen_btn: TextureButton = $HBoxContainer/SameScreenBtn
@onready var settings = EditorInterface.get_editor_settings()

var accent_color: Color
var current_run_screen: int = 0
var popup: Popup


func _ready() -> void:
	settings.settings_changed.connect(_on_settings_changed)
	_on_settings_changed()
	next_screen_btn.pressed.connect(_on_next_screen_btn_pressed)
	same_screen_btn.pressed.connect(_on_same_screen_btn_pressed)
	next_screen_btn.mouse_entered.connect(_on_btn_hover.bind(next_screen_btn))
	same_screen_btn.mouse_entered.connect(_on_btn_hover.bind(same_screen_btn))
	next_screen_btn.mouse_exited.connect(_on_btn_exit.bind(next_screen_btn))
	same_screen_btn.mouse_exited.connect(_on_btn_exit.bind(same_screen_btn))

func _on_settings_changed() -> void:
	accent_color = settings.get_setting("interface/theme/accent_color")
	current_run_screen = settings.get_setting("run/window_placement/screen")
	match current_run_screen:
		-3:
			next_screen_btn.modulate = accent_color
			same_screen_btn.modulate = default_color
		-2:
			same_screen_btn.modulate = accent_color
			next_screen_btn.modulate = default_color
		_:
			next_screen_btn.modulate = default_color
			same_screen_btn.modulate = default_color

func _on_next_screen_btn_pressed() -> void:
	next_screen_btn.modulate = accent_color
	same_screen_btn.modulate = default_color
	settings.set_setting("run/window_placement/screen", next_screen_btn.get_meta("screen_index"))

func _on_same_screen_btn_pressed() -> void:
	same_screen_btn.modulate = accent_color
	next_screen_btn.modulate = default_color
	settings.set_setting("run/window_placement/screen", same_screen_btn.get_meta("screen_index"))

func _on_btn_hover(button: TextureButton) -> void:
	button.modulate = hover_color if current_run_screen != button.get_meta("screen_index") else accent_color
	if popup: popup.queue_free()
	popup = preload("res://addons/screen_config_plugin/HoverPopup.tscn").instantiate()
	add_child(popup)
	popup.position = get_screen_position() + get_local_mouse_position() + Vector2(24, 24)
	popup.popup()
	popup.hide()
	var pos_to_check_after_await: Vector2i = popup.position
	popup.get_node("Panel/Label").text = button.get_meta("Text")
	await get_tree().create_timer(0.7, true, false, true).timeout
	if popup and popup.position == pos_to_check_after_await:
		popup.show()

func _on_btn_exit(button: TextureButton) -> void:
	button.modulate = default_color if current_run_screen != button.get_meta("screen_index") else accent_color

	if popup: popup.queue_free()
	popup = null
