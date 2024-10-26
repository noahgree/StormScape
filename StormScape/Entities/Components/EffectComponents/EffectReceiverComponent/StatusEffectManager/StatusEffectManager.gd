@icon("res://Utilities/Debug/EditorIcons/effect_modifier_component.svg")
extends Node
class_name StatusEffectManager
## The component that holds the stats and logic for how the entity should receive effects.
##
## This handles things like fire & poison damage not taking into account armor, etc.

var current_effects: Dictionary = {} ## Keys are general status effect titles like "Poison", and values are arrays of all integer levels of the status effect currently applied.
var effect_timers: Dictionary = {} ## Holds references to all timers currently tracking active status effects.

@onready var receiver: EffectReceiverComponent = get_parent()

## Handles an incoming status effect. It starts by adding any stat mods provided by the status effect, and then
## it passes the effect logic to the relevant handler if it exists.
func handle_status_effect(status_effect: StatusEffect) -> void:
	if get_parent().can_receive_stat_mods:
		handle_status_effect_mods(status_effect)
	
	match status_effect.handler_type:
		GlobalData.EntityStatusEffectType.KNOCKBACK:
			if receiver.knockback_handler: receiver.knockback_handler.handle_knockback(status_effect)
		GlobalData.EntityStatusEffectType.STUN:
			if receiver.stun_handler: receiver.stun_handler.handle_stun(status_effect)
		GlobalData.EntityStatusEffectType.POISON:
			if receiver.poison_handler: receiver.poison_handler.handle_poison(status_effect)
		GlobalData.EntityStatusEffectType.REGEN:
			if receiver.regen_handler: receiver.regen_handler.handle_regen(status_effect)
		GlobalData.EntityStatusEffectType.FROSTBITE:
			if receiver.frostbite_handler: receiver.frostbite_handler.handle_frostbite(status_effect)
		GlobalData.EntityStatusEffectType.BURNING:
			if receiver.burning_handler: receiver.burning_handler.handle_burning(status_effect)
		GlobalData.EntityStatusEffectType.TIMESNARE:
			if receiver.time_snare_handler: receiver.time_snare_handler.handle_time_snare(status_effect)

## Checks if we already have a status effect of the same name and decides what to do depending on the level.
func handle_status_effect_mods(status_effect: StatusEffect) -> void:
	if status_effect.effect_name in current_effects:
		var existing_lvl = current_effects[status_effect.effect_name].effect_lvl
		
		if existing_lvl > status_effect.effect_lvl: # new effect is lower lvl
			var time_to_add: float = status_effect.mod_time * (float(status_effect.effect_lvl) / float(existing_lvl))
			_extend_effect_duration(status_effect.effect_name, time_to_add)
			return
		elif existing_lvl < status_effect.effect_lvl: # new effect is higher lvl
			_remove_status_effect(current_effects[status_effect.effect_name])
			add_status_effect(status_effect)
			return
		else: # new effect is same lvl
			_restart_effect_duration(status_effect.effect_name)
			return
	else:
		add_status_effect(status_effect)

## Adds a status effect to the current effects dict, starts its timer, stores its timer, and applies its mods.
func add_status_effect(status_effect: StatusEffect) -> void:
	current_effects[status_effect.effect_name] = status_effect

	var mod_timer: Timer = Timer.new()
	mod_timer.wait_time = max(0.001, status_effect.mod_time)
	mod_timer.one_shot = true
	mod_timer.timeout.connect(func(): _remove_status_effect(status_effect))
	mod_timer.name = str(status_effect.effect_name) + str(status_effect.effect_lvl) + "_timer"
	add_child(mod_timer)
	mod_timer.start()
	
	effect_timers[status_effect.effect_name] = mod_timer
	
	for mod_resource in status_effect.stat_mods:
		var mod: EntityStatMod = (mod_resource as EntityStatMod)
		
		match mod.type:
			GlobalData.EntityStatModType.VITALS:
				if receiver.health_component: receiver.health_component.add_mods([mod])
			GlobalData.EntityStatModType.STAMINA:
				if receiver.stamina_component: receiver.stamina_component.add_mods([mod])
			GlobalData.EntityStatModType.MOVEMENT:
				receiver.affected_entity.move_fsm.add_mods(([mod] as Array[EntityStatMod]))
			GlobalData.EntityStatModType.DAMAGE:
				if receiver.dmg_handler: receiver.dmg_handler.add_mods([mod])
			GlobalData.EntityStatModType.HEALING:
				if receiver.heal_handler: receiver.heal_handler.add_mods([mod])
			GlobalData.EntityStatModType.KNOCKBACK:
				if receiver.knockback_handler: receiver.knockback_handler.add_mods([mod])
			GlobalData.EntityStatModType.STUN:
				if receiver.stun_handler: receiver.stun_handler.add_mods([mod])
			GlobalData.EntityStatModType.POISON:
				if receiver.poison_handler: receiver.poison_handler.add_mods([mod])
			GlobalData.EntityStatModType.REGEN: 
				if receiver.regen_handler: receiver.regen_handler.add_mods([mod])
			GlobalData.EntityStatModType.FROSTBITE: 
				if receiver.frostbite_handler: receiver.frostbite_handler.add_mods([mod])
			GlobalData.EntityStatModType.BURNING:
				if receiver.burning_handler: receiver.burning_handler.add_mods([mod])
			GlobalData.EntityStatModType.TIMESNARE:
				if receiver.time_snare_handler: receiver.time_snare_handler.add_mods([mod])
	
	print_rich("[color=green]added[/color] " + str(status_effect.effect_name) + ": " + str(current_effects.keys()))

## Extends the duration of the timer associated with some current effect.
func _extend_effect_duration(effect_name: String, time_to_add: float) -> void:
	var timer: Timer = effect_timers.get(effect_name, null)
	if timer != null:
		print(timer.get_time_left())
		print(time_to_add)
		var new_time: float = timer.get_time_left() + time_to_add
		timer.stop()
		timer.wait_time = new_time
		timer.start()
		print(timer.get_time_left())

## Restarts the timer associated with some current effect.
func _restart_effect_duration(effect_name: String) -> void:
	var timer: Timer = effect_timers.get(effect_name, null)
	if timer != null:
		timer.stop()
		timer.start()

## Removes the status effect from the current effects dict and removes all its mods. Additionally removes its
## associated timer from the timer dict.
func _remove_status_effect(status_effect: StatusEffect) -> void:
	for mod_resource in status_effect.stat_mods:
		var mod: EntityStatMod = (mod_resource as EntityStatMod)
		
		match mod.type:
			GlobalData.EntityStatModType.VITALS:
				if receiver.health_component: receiver.health_component.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.STAMINA:
				if receiver.stamina_component: receiver.stamina_component.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.MOVEMENT:
				receiver.affected_entity.move_fsm.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.DAMAGE:
				if receiver.dmg_handler: receiver.dmg_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.HEALING:
				if receiver.heal_handler: receiver.heal_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.KNOCKBACK:
				if receiver.knockback_handler: receiver.knockback_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.STUN:
				if receiver.stun_handler: receiver.stun_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.POISON:
				if receiver.poison_handler: receiver.poison_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.REGEN:
				if receiver.regen_handler: receiver.regen_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.FROSTBITE:
				if receiver.frostbite_handler: receiver.frostbite_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.BURNING:
				if receiver.burning_handler: receiver.burning_handler.remove_mod(mod.stat_id, mod.mod_id)
			GlobalData.EntityStatModType.TIMESNARE:
				if receiver.time_snare_handler: receiver.time_snare_handler.remove_mod(mod.stat_id, mod.mod_id)
	
	if status_effect.effect_name in current_effects:
		current_effects.erase(status_effect.effect_name)
	
	var timer: Timer = effect_timers.get(status_effect.effect_name, null)
	if timer != null:
		timer.stop()
		timer.queue_free()
		effect_timers.erase(status_effect.effect_name)
	
	print_rich("[color=magenta]removed[/color] " + str(status_effect.effect_name) + ": " + str(current_effects.keys()))

## Loads the necessary movement and contact data from the effect source into the knockback handler.
func prepare_knockback_vars(effect_source: EffectSource) -> void:
	if receiver.knockback_handler:
		receiver.knockback_handler.contact_position = effect_source.contact_position
		receiver.knockback_handler.effect_movement_direction = effect_source.movement_direction
		receiver.knockback_handler.is_source_moving_type = effect_source.is_source_moving_type

## Returns if any effect (no matter the level) of the passed in name is active.
func check_if_effect(effect_name: String) -> bool:
	return current_effects.has(effect_name)

## Attempts to remove any effect of the matching name and then tries to cancel any active DOTs and HOTs for it.
func request_effect_removal(effect_name: String) -> void:
	var existing_effect: StatusEffect = current_effects.get(effect_name, null)
	if existing_effect: _remove_status_effect(existing_effect)
	
	if receiver.dmg_handler: receiver.dmg_handler.cancel_over_time_dmg(effect_name)
	if receiver.heal_handler: receiver.heal_handler.cancel_over_time_heal(effect_name)

## Removes all bad status effects except for an optional exception effect that may be specified.
func remove_all_bad_status_effects(effect_to_keep: String = "") -> void:
	for status_effect in current_effects.keys():
		if effect_to_keep != "" and effect_to_keep == status_effect:
			continue
		elif status_effect in GlobalData.BAD_STATUS_EFFECTS:
			request_effect_removal(status_effect)

## Removes all good status effects except for an optional exception effect that may be specified.
func remove_all_good_status_effects(effect_to_keep: String = "") -> void:
	for status_effect in current_effects.keys():
		if effect_to_keep != "" and effect_to_keep == status_effect:
			continue
		elif status_effect in GlobalData.GOOD_STATUS_EFFECTS:
			request_effect_removal(status_effect)
