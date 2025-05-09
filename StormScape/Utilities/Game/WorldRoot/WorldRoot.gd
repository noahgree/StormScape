extends Node2D
class_name WorldRoot
## The root of the active game world. Everything begins here. Mark this node and children of this node
## that should never unload as being in the "core" group within the global group tab.

@onready var fps_label: Label = $DebugCanvasLayer/FPS ## The label displaying the current FPS.


func _ready() -> void:
	if DebugFlags.frame_rate:
		set_process(true)
	else:
		set_process(false)
		fps_label.text = ""

func _process(_delta: float) -> void:
	if DebugFlags.frame_rate:
		fps_label.text = str(int(Engine.get_frames_per_second()))
	else:
		fps_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_stop"):
		assert(false)
