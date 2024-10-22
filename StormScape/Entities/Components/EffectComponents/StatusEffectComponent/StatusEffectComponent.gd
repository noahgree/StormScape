@icon("res://Utilities/Debug/EditorIcons/effect_modifier_component.svg")
extends Node
class_name StatusEffectComponent
## The component that holds the stats and logic for how the entity should receive effects.
##
## This handles things like fire & poison damage not taking into account armor, etc.

@export var health_component: HealthComponent
@export var stamina_component: StaminaComponent
@export var move_fsm: MoveStateMachine
@export var dmg_handler: DmgHandler
@export var heal_handler: HealHandler
@export var knockback_handler: KnockbackHandler
@export var stun_handler: StunHandler
@export var poison_handler: PoisonHandler
@export var regen_handler: RegenHandler
@export var frostbite_handler: FrostbiteHandler

var current_effects: Dictionary = {} ## Keys are general status effect titles like "Poison", and values are arrays of all integer levels of the status effect currently applied.
var effect_timers: Dictionary = {}


## Handles an incoming status effect. It starts by sending relevant info to its handler if it exists, 
## then it handles stat mods via a helper function.
func handle_status_effect(status_effect: StatusEffect) -> void:
	match status_effect.handler_type:
		EnumUtils.EntityStatusEffectType.KNOCKBACK:
			if knockback_handler: knockback_handler.handle_knockback(status_effect)
		EnumUtils.EntityStatusEffectType.STUN:
			if stun_handler: stun_handler.handle_stun(status_effect)
		EnumUtils.EntityStatusEffectType.POISON:
			if poison_handler: poison_handler.handle_poison(status_effect)
		EnumUtils.EntityStatusEffectType.REGEN:
			if regen_handler: regen_handler.handle_regen(status_effect)
		EnumUtils.EntityStatusEffectType.FROSTBITE:
			if frostbite_handler: frostbite_handler.handle_frostbite(status_effect)
	
	handle_status_effect_mods(status_effect)

## Checks if we already have a status effect of the same name and decides what to do depending on the level.
func handle_status_effect_mods(status_effect: StatusEffect) -> void:
	if status_effect.effect_name in current_effects:
		var existing_lvl = current_effects[status_effect.effect_name].effect_lvl
		
		if existing_lvl > status_effect.effect_lvl: # new effect is lower lvl
			var time_to_add: float = status_effect.effect_mods_time * (status_effect.effect_lvl / existing_lvl)
			_extend_effect_duration(status_effect.effect_name, time_to_add)
			return
		elif existing_lvl < status_effect.effect_lvl: # new effect is higher lvl
			remove_status_effect(current_effects[status_effect.effect_name])
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
	mod_timer.wait_time = status_effect.effect_mods_time
	mod_timer.one_shot = true
	mod_timer.timeout.connect(func(): remove_status_effect(status_effect))
	add_child(mod_timer)
	mod_timer.start()
	
	effect_timers[status_effect.effect_name] = mod_timer
	
	for mod_resource in status_effect.stat_mods:
		var mod: EntityStatMod = (mod_resource as EntityStatMod)
		
		match mod.type:
			EnumUtils.EntityStatModType.VITALS:
				if health_component: health_component.add_mods([mod])
			EnumUtils.EntityStatModType.STAMINA:
				if stamina_component: stamina_component.add_mods([mod])
			EnumUtils.EntityStatModType.MOVEMENT:
				if move_fsm: move_fsm.add_mods([mod])
			EnumUtils.EntityStatModType.DAMAGE:
				if dmg_handler: dmg_handler.add_mods([mod])
			EnumUtils.EntityStatModType.HEALING:
				if heal_handler: heal_handler.add_mods([mod])
			EnumUtils.EntityStatModType.KNOCKBACK:
				if knockback_handler: knockback_handler.add_mods([mod])
			EnumUtils.EntityStatModType.STUN:
				if stun_handler: stun_handler.add_mods([mod])
			EnumUtils.EntityStatModType.POISON:
				if poison_handler: poison_handler.add_mods([mod])
			EnumUtils.EntityStatModType.REGEN: 
				if regen_handler: regen_handler.add_mods([mod])
			EnumUtils.EntityStatModType.FROSTBITE: 
				if frostbite_handler: frostbite_handler.add_mods([mod])

## Extends the duration of the timer associated with some current effect.
func _extend_effect_duration(effect_name: String, time_to_add: float) -> void:
	var timer: Timer = effect_timers.get(effect_name, null)
	if timer:
		var new_time: float = timer.get_time_left() + time_to_add
		timer.stop()
		timer.wait_time = new_time
		timer.start()

## Restarts the timer associated with some current effect.
func _restart_effect_duration(effect_name: String) -> void:
	var timer: Timer = effect_timers.get(effect_name, null)
	if timer:
		timer.stop()
		timer.start()

## Removes the status effect from the current effects dict and removes all its mods.
func remove_status_effect(status_effect: StatusEffect) -> void:
	for mod_resource in status_effect.stat_mods:
		var mod: EntityStatMod = (mod_resource as EntityStatMod)
		
		match mod.type:
			EnumUtils.EntityStatModType.VITALS:
				if health_component: health_component.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.STAMINA:
				if stamina_component: stamina_component.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.MOVEMENT:
				if move_fsm: move_fsm.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.DAMAGE:
				if dmg_handler: dmg_handler.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.HEALING:
				if heal_handler: heal_handler.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.KNOCKBACK:
				if knockback_handler: knockback_handler.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.STUN:
				if stun_handler: stun_handler.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.POISON:
				if poison_handler: poison_handler.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.REGEN:
				if regen_handler: regen_handler.remove_mod(mod.stat_id, mod.mod_id)
			EnumUtils.EntityStatModType.FROSTBITE:
				if frostbite_handler: frostbite_handler.remove_mod(mod.stat_id, mod.mod_id)
	
	current_effects.erase(status_effect.effect_name)
	
	var timer: Timer = effect_timers.get(status_effect.effect_name, null)
	if timer:
		timer.stop()
		timer.queue_free()
		effect_timers.erase(status_effect.effect_name)
