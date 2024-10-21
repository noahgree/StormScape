extends Control
## Debugging script for having buttons on screen that do test actions.

@export var health_component: HealthComponent


func _on_test_hurt_btn_pressed() -> void:
	health_component.damage_shield_then_health(12)

func _on_test_heal_btn_pressed() -> void:
	health_component.heal_health_then_shield(15)

func _on_test_music_btn_pressed() -> void:
	AudioManager.play_sound("SummerTide", AudioManager.SoundType.SFX_GLOBAL)
	await get_tree().create_timer(2).timeout
	AudioManager.fade_out_sounds("SummerTide", 1.0, 1)

func _on_test_mod_btn_1_pressed() -> void:
	var node = get_parent().get_parent().stamina_component
	var mod = EntityStatMod.new("mod1", "*", 2, 1, true, 2)
	node.add_mod("stamina_use_per_hunger_deduction", mod)

func _on_test_mod_btn_2_pressed() -> void:
	var node = get_parent().get_parent().stamina_component
	node.remove_mod("stamina_use_per_hunger_deduction", "mod1", 1)
