@icon("res://Utilities/Debug/EditorIcons/effect_receiver_component.svg")
extends Area2D
class_name EffectReceiverComponent
## A general effect source receiver that passes the appropriate parts of the effect to handlers, but only if 
## they exist as children. This node must have an attached collision shape to define where effects are received.
##
## Add specific effect handlers as children of this node to be able to receive those effects on the entity.
## For all intensive purposes, this is acting as a hurtbox component via its receiver area.

@export var status_effect_component: StatusEffectComponent ## The optional component attached to the affected entity that handles modifying incoming values based on stats of the entity.
@export var health_component: HealthComponent ## The connected health component to receive damage and healing if the parent entity can handle it.
@export var affected_entity: PhysicsBody2D  ## The connected entity to be affected by the effects be received.


## Asserts that the affected entity has been set for easy debugging, then sets the monitoring to off for 
## performance reasons in case it was changed in the editor. It also ensures the collision layer is the same as the 
## affected entity so that the effect sources only see it when they should.
func _ready() -> void:
	assert(affected_entity, get_parent().name + " has an effect receiver that is missing a reference to an entity.")
	collision_layer = affected_entity.collision_layer
	monitoring = false

## Handles an incoming effect source, passing it to present receivers for further processing before changing 
## entity stats.
func handle_effect_source(effect_source: EffectSource) -> void:
	if (affected_entity is DynamicEntity) and not affected_entity.move_fsm.can_receive_effects:
		return
	
	if effect_source.base_damage > 0 and has_node("DmgHandler"):
		if _check_same_team(effect_source) and _check_dmg_allies(effect_source):
			$DmgHandler.handle_base_damage(effect_source)
		elif not _check_same_team(effect_source) and _check_dmg_enemies(effect_source):
			$DmgHandler.handle_base_damage(effect_source)
	
	if effect_source.base_healing > 0 and has_node("HealHandler"):
		if effect_source.base_healing > 0:
			if _check_same_team(effect_source) and _check_heal_allies(effect_source):
				$HealHandler.handle_instant_heal(effect_source.base_healing, effect_source.heal_affected_stats)
			elif not _check_same_team(effect_source) and _check_heal_enemies(effect_source):
				$HealHandler.handle_instant_heal(effect_source.base_healing, effect_source.heal_affected_stats)
	
	if has_node("KnockbackHandler"):
		status_effect_component.prepare_knockback_vars(effect_source)
	
	for status_effect in effect_source.status_effects:
		if status_effect:
			status_effect_component.handle_status_effect(status_effect)

## Checks if the affected entity is on the same team as the producer of the effect source.
func _check_same_team(effect_source: EffectSource) -> bool:
	print(affected_entity.team & effect_source.source_team != 0)
	return affected_entity.team & effect_source.source_team != 0

## Checks if the effect source should do bad effects to allies. 
func _check_dmg_allies(effect_source: EffectSource) -> bool:
	return effect_source.bad_effect_affected_teams & EnumUtils.BadEffectAffectedTeams.ALLIES != 0

## Checks if the effect source should do bad effects to enemies. 
func _check_dmg_enemies(effect_source: EffectSource) -> bool:
	return effect_source.bad_effect_affected_teams & EnumUtils.BadEffectAffectedTeams.ENEMIES != 0

## Checks if the effect source should do good effects to allies.
func _check_heal_allies(effect_source: EffectSource) -> bool:
	return effect_source.good_effect_affected_teams & EnumUtils.GoodEffectAffectedTeams.ALLIES != 0

## Checks if the effect source should do good effects to enemies.
func _check_heal_enemies(effect_source: EffectSource) -> bool:
	return effect_source.good_effect_affected_teams & EnumUtils.GoodEffectAffectedTeams.ENEMIES != 0
