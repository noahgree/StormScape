extends Control
## Debugging script for having buttons on screen that do test actions.

@export var health_component: HealthComponent
@export var mods: Array[WeaponMod]


func _on_test_hurt_btn_pressed() -> void:
	health_component.damage_shield_then_health(12, "BasicDamage")

func _on_test_heal_btn_pressed() -> void:
	health_component.heal_health_then_shield(15, "BasicHealing")

func _on_test_music_btn_pressed() -> void:
	var audio_player: Variant = AudioManager.play_and_get_sound("MysteryTheme1", AudioManager.SoundType.MUSIC_2D, GlobalData.player_node, 0)
	if audio_player:
		#AudioManager.play_sound("PowerUp3", AudioManager.SoundType.SFX_GLOBAL)
		await get_tree().create_timer(15).timeout
		#AudioManager.fade_out_sounds("SummerTide", 1.0, 1)
		AudioManager.stop_audio_player(audio_player)

func _on_test_mod_btn_1_pressed() -> void:
	#var stats_ui: Control = get_parent().get_node("PlayerStatsOverlay")
	#var mod = StatMod.new("stamina_use_per_hunger_deduction", "mod1", "-%", 10, 1, true, 2, false)
	#var mod2 = StatMod.new("stamina_use_per_hunger_deduction", "mod2", "=", 2, 2, true, 5, true)
	#var arr: Array[StatMod] = [mod, mod2]
	#get_parent().get_parent().stats.add_mods(arr, stats_ui)
	for mod: WeaponMod in mods:
		GlobalData.player_node.hands.equipped_item.weapon_mod_manager.handle_weapon_mod(mod)

func _on_test_mod_btn_2_pressed() -> void:
	#var stats_ui: Control = get_parent().get_node("PlayerStatsOverlay")
	#get_parent().get_parent().stats.remove_mod("stamina_use_per_hunger_deduction", "mod2", stats_ui, 1)
	#get_parent().get_parent().stats.remove_mod("stamina_use_per_hunger_deduction", "mod1", stats_ui, 1)
	for mod: WeaponMod in mods:
		GlobalData.player_node.hands.equipped_item.weapon_mod_manager.request_mod_removal(mod.mod_name)

func _on_test_mod_btn_3_pressed() -> void:
	if GlobalData.storm.is_enabled:
		GlobalData.storm.disable_storm()
	else:
		GlobalData.storm.enable_storm()

func _on_test_save_btn_pressed() -> void:
	SaverLoader.save_game()

func _on_test_load_btn_pressed() -> void:
	SaverLoader.load_game()

func _on_test_storm_btn_2_pressed() -> void:
	GlobalData.storm.force_start_next_phase()

func _on_test_combine_items_pressed() -> void:
	GlobalData.world_root.get_node("WorldItemsManager")._on_combination_attempt_timer_timeout()
