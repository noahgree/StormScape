extends Resource
class_name SoundResource


@export var name: String
@export_file("*.mp3", "*.wav", "*.ogg") var sound_file_path: String
@export_range(1, 10, 1) var concurrent_limit: int = 1
@export_range(-40, 20, 0.1, "suffix:db") var volume = 0
@export_range(0.0, 4.0, 0.01) var pitch_scale = 1.0
@export_range(0.0, 1.0, 0.01) var pitch_randomness = 0.0

var current_count = 0

func change_current_count(amount: int) -> void:
	current_count = max(0, current_count + amount)

func has_available_stream() -> bool:
	return current_count < concurrent_limit

func on_audio_finished() -> void:
	change_current_count(-1)
