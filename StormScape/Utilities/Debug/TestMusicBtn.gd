extends Button


func _on_pressed() -> void:
	AudioManager.play_sound("SummerTide", AudioManager.SoundType.SFX_GLOBAL)
	
	await get_tree().create_timer(2).timeout
	
	AudioManager.fade_out_sounds("SummerTide", 1.0, 1)
