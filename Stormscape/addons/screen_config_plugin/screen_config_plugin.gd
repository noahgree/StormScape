@tool
extends EditorPlugin

var toolbar: Control


func _enter_tree() -> void:
	toolbar = preload("res://addons/screen_config_plugin/ScreenConfigToolbar.tscn").instantiate()
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, toolbar)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, toolbar)
	toolbar.queue_free()
