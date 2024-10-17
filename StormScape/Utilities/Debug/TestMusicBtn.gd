extends Button


func _on_pressed() -> void:
	AudioManager.create_sound("SummerTide", AudioManager.SoundType.SFX_GLOBAL)
	await get_tree().create_timer(1).timeout
	AudioManager.create_sound("SummerTide", AudioManager.SoundType.SFX_GLOBAL)
	await get_tree().create_timer(1.5).timeout
	AudioManager.create_sound("SummerTide", AudioManager.SoundType.SFX_GLOBAL)
	await get_tree().create_timer(6).timeout
	
	AudioManager.stop_sounds("SummerTide", 2)
	
	await get_tree().create_timer(1).timeout
	
	AudioManager.stop_sounds("SummerTide", 2)
