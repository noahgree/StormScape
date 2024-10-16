extends Button


func _on_pressed() -> void:
	AudioManager.create_sound("MysteryTheme1", AudioManager.SoundType.MUSIC_GLOBAL)
