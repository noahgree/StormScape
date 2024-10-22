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
	var mod = EntityStatMod.new("stamina_use_per_hunger_deduction", "mod1", "-%", 10, 1, true, 2, false)
	var mod2 = EntityStatMod.new("stamina_use_per_hunger_deduction", "mod2", "=", 2, 2, true, 5, true)
	var arr: Array[EntityStatMod] = [mod, mod2]
	node.add_mods(arr)

func _on_test_mod_btn_2_pressed() -> void:
	var node = get_parent().get_parent().stamina_component
	node.remove_mod("stamina_use_per_hunger_deduction", "mod2", 1)
	node.remove_mod("stamina_use_per_hunger_deduction", "mod1", 1)
