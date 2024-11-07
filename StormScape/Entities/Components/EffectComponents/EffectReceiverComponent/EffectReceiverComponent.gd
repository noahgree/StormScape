@icon("res://Utilities/Debug/EditorIcons/effect_receiver_component.svg")
@tool
extends Area2D
class_name EffectReceiverComponent
## A general effect source receiver that passes the appropriate parts of the effect to handlers, but only if
## they exist as children. This node must have an attached collision shape to define where effects are received.
##
## Add specific effect handlers as children of this node to be able to receive those effects on the entity.
## For all intensive purposes, this is acting as a hurtbox component via its receiver area.

@export var can_receive_status_effects: bool = true ## Whether the affected entity can have status effects applied at all. This does not include base damage and base healing.
@export var can_receive_stat_mods: bool = true ## Whether the affected entity can have its stats modded via received effect sources.
@export_group("Connected Nodes")
@export var affected_entity: PhysicsBody2D  ## The connected entity to be affected by the effects be received.
@export var health_component: HealthComponent
@export var stamina_component: StaminaComponent
@export_subgroup("Handlers")
@export var dmg_handler: DmgHandler
@export var heal_handler: HealHandler
@export var knockback_handler: KnockbackHandler
@export var stun_handler: StunHandler
@export var poison_handler: PoisonHandler
@export var regen_handler: RegenHandler
@export var frostbite_handler: FrostbiteHandler
@export var burning_handler: BurningHandler
@export var time_snare_handler: TimeSnareHandler

@onready var tool_script: Node = $EffectReceiverToolScript


## This works with the tool script defined above to assign export vars automatically in-editor once added to the tree.
func _notification(what):
	if Engine.is_editor_hint():
		if what == NOTIFICATION_CHILD_ORDER_CHANGED:
			if tool_script: tool_script.update_editor_children_exports(self, get_children())
		elif what == NOTIFICATION_ENTER_TREE:
			if tool_script: tool_script.update_editor_parent_export(self, get_parent())

## Asserts that the affected entity has been set for easy debugging, then sets the monitoring to off for
## performance reasons in case it was changed in the editor. It also ensures the collision layer is the same as the
## affected entity so that the effect sources only see it when they should.
func _ready() -> void:
	assert(affected_entity or get_parent() is SubViewport, get_parent().name + " has an effect receiver that is missing a reference to an entity.")
	if can_receive_status_effects: assert(get_parent().has_node("StatusEffectManager"), get_parent().name + " has an effect receiver flagged as being able to handle status effects, yet has no StatusEffectManager.")
	if not Engine.is_editor_hint():
		collision_layer = affected_entity.collision_layer
		monitoring = false

## Handles an incoming effect source, passing it to present receivers for further processing before changing
## entity stats.
func handle_effect_source(effect_source: EffectSource) -> void:
	if effect_source.source_team == GlobalData.Teams.PASSIVE:
		return
	if (affected_entity is DynamicEntity) and not affected_entity.move_fsm.can_receive_effects:
		return

	if (affected_entity is Player):
		if effect_source.cam_shake_duration > 0:
			GlobalData.player_camera.start_shake(effect_source.cam_shake_strength, effect_source.cam_shake_duration)
		if effect_source.cam_freeze_duration > 0:
			GlobalData.player_camera.start_freeze(effect_source.cam_freeze_multiplier, effect_source.cam_freeze_duration)

	if effect_source.base_damage > 0 and has_node("DmgHandler"):
		if _check_same_team(effect_source) and _check_if_bad_effects_apply_to_allies(effect_source):
			$DmgHandler.handle_instant_damage(effect_source)
		elif not _check_same_team(effect_source) and _check_if_bad_effects_apply_to_enemies(effect_source):
			$DmgHandler.handle_instant_damage(effect_source)

	if effect_source.base_healing > 0 and has_node("HealHandler"):
		if effect_source.base_healing > 0:
			if _check_same_team(effect_source) and _check_if_good_effects_apply_to_allies(effect_source):
				$HealHandler.handle_instant_heal(effect_source.base_healing, effect_source.heal_affected_stats)
			elif not _check_same_team(effect_source) and _check_if_good_effects_apply_to_enemies(effect_source):
				$HealHandler.handle_instant_heal(effect_source.base_healing, effect_source.heal_affected_stats)

	if can_receive_status_effects:
		if has_node("KnockbackHandler"):
			knockback_handler.contact_position = effect_source.contact_position
			knockback_handler.effect_movement_direction = effect_source.movement_direction
			knockback_handler.is_source_moving_type = effect_source.is_source_moving_type

		_unpack_status_effects_from_source(effect_source)

## Handles the array of status effects coming in from the effect source by sending each status effect to the manager.
func _unpack_status_effects_from_source(effect_source: EffectSource) -> void:
	var do_bad_effects: bool = not _check_same_team(effect_source) and _check_if_bad_effects_apply_to_enemies(effect_source)
	var do_good_effects: bool = not _check_same_team(effect_source) and _check_if_good_effects_apply_to_enemies(effect_source)

	for status_effect in effect_source.status_effects:
		if status_effect:
			if (not do_bad_effects or "Untouchable" in affected_entity.effects.current_effects) and (status_effect.is_bad_effect):
				continue
			if (not do_good_effects) and (not status_effect.is_bad_effect):
				continue

			for effect_to_stop in status_effect.effects_to_stop:
				affected_entity.effects.request_effect_removal(effect_to_stop)

			if (affected_entity is not Player) and status_effect.only_cue_on_player_hit:
				pass
			else:
				if status_effect.audio_to_play != "":
					AudioManager.play_sound(status_effect.audio_to_play, AudioManager.SoundType.SFX_2D, affected_entity.global_position)

			_pass_effect_to_handler(status_effect)

	if "Untouchable" in affected_entity.effects.current_effects:
		affected_entity.effects.remove_all_bad_status_effects()

func _pass_effect_to_handler(status_effect: StatusEffect) -> void:
	affected_entity.effects.handle_status_effect(status_effect)
	match status_effect.handler_type:
		GlobalData.EntityStatusEffectType.KNOCKBACK:
			if knockback_handler: knockback_handler.handle_knockback(status_effect)
		GlobalData.EntityStatusEffectType.STUN:
			if stun_handler: stun_handler.handle_stun(status_effect)
		GlobalData.EntityStatusEffectType.POISON:
			if poison_handler: poison_handler.handle_poison(status_effect)
		GlobalData.EntityStatusEffectType.REGEN:
			if regen_handler: regen_handler.handle_regen(status_effect)
		GlobalData.EntityStatusEffectType.FROSTBITE:
			if frostbite_handler: frostbite_handler.handle_frostbite(status_effect)
		GlobalData.EntityStatusEffectType.BURNING:
			if burning_handler: burning_handler.handle_burning(status_effect)
		GlobalData.EntityStatusEffectType.TIMESNARE:
			if time_snare_handler: time_snare_handler.handle_time_snare(status_effect)

## Checks if the affected entity is on the same team as the producer of the effect source.
func _check_same_team(effect_source: EffectSource) -> bool:
	return affected_entity.team & effect_source.source_team != 0

## Checks if the effect source should do bad effects to allies.
func _check_if_bad_effects_apply_to_allies(effect_source: EffectSource) -> bool:
	return effect_source.bad_effect_affected_teams & GlobalData.BadEffectAffectedTeams.ALLIES != 0

## Checks if the effect source should do bad effects to enemies.
func _check_if_bad_effects_apply_to_enemies(effect_source: EffectSource) -> bool:
	return effect_source.bad_effect_affected_teams & GlobalData.BadEffectAffectedTeams.ENEMIES != 0

## Checks if the effect source should do good effects to allies.
func _check_if_good_effects_apply_to_allies(effect_source: EffectSource) -> bool:
	return effect_source.good_effect_affected_teams & GlobalData.GoodEffectAffectedTeams.ALLIES != 0

## Checks if the effect source should do good effects to enemies.
func _check_if_good_effects_apply_to_enemies(effect_source: EffectSource) -> bool:
	return effect_source.good_effect_affected_teams & GlobalData.GoodEffectAffectedTeams.ENEMIES != 0
