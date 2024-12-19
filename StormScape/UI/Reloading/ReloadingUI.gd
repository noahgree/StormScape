extends Control

@onready var progress_bar: TextureProgressBar = $ProgressBar


func _ready() -> void:
	hide()

func update_progress(value: int) -> void:
	progress_bar.value = value

func update_max_progress(max_value: int) -> void:
	progress_bar.max_value = max_value
