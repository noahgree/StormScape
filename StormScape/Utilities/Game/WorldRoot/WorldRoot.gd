extends Node2D
class_name WorldRoot

@onready var fps_label: Label = $DebugCanvasLayer/FPS


func _ready() -> void:
	if DebugFlags.OnScreenDebug.frame_rate:
		set_process(true)
	else:
		set_process(false)
		fps_label.text = ""

func _process(_delta: float) -> void:
	fps_label.text = str(Engine.get_frames_per_second())
