@icon("res://Utilities/Debug/EditorIcons/effect_receiver_component.svg")
extends Area2D
class_name EffectReceiverComponent
## A general effect source receiver that passes the appropriate parts of the effect to handlers, but only if 
## they exist as children. This node must have an attached collision shape to define where effects are received.
##
## Add specific effect handlers as children of this node to be able to receive those effects on the entity.
## For all intensive purposes, this is acting as a hurtbox component.

@export var health_component: HealthComponent ## The connected health component to receive damage and healing if the parent entity can handle it.
@export var affected_entity: PhysicsBody2D  ## The connected entity to be affected by the effects be received.
@export var team: EnumUtils.Teams = EnumUtils.Teams.PLAYER ## What team the effects being received should consider the affected entity as being on.


## Asserts that the affected entity has been set for easy debugging, then sets the monitoring to off for 
## performance reasons in case it was changed in the editor. It also ensures the collision layer is the same as the 
## affected entity so that the effect sources only see it when they should.
func _ready() -> void:
	assert(affected_entity, get_parent().name + " has an effect receiver that is missing a reference to an entity.")
	collision_layer = affected_entity.collision_layer
	monitoring = false

## Handles an incoming effect source, passing it to present receivers for further processing before changing 
## entity stats.
func handle_effect(effect_source: EffectSource) -> void:
	if has_node("KnockbackEffectHandler"):
		if effect_source.knockback_force != 0:
			_run_knockback_handler(effect_source)
	
	if effect_source.source_team == EnumUtils.Teams.PASSIVE:
		_run_stun_handler(effect_source)
		return
	
	if has_node("DmgEffectHandler"):
		if effect_source.base_damage > 0:
			if _check_same_team(effect_source) and _check_dmg_allies(effect_source):
				_run_dmg_handler(effect_source)
			elif not _check_same_team(effect_source) and _check_dmg_enemies(effect_source):
				_run_dmg_handler(effect_source)

	if has_node("HealEffectHandler"):
		if effect_source.base_healing > 0:
			if _check_same_team(effect_source) and _check_heal_allies(effect_source):
				_run_heal_handler(effect_source)
			elif not _check_same_team(effect_source) and _check_heal_enemies(effect_source):
				_run_heal_handler(effect_source)

## Starts the damage handler based on the damage timeline in the effect source. Also calls the stun handler to start.
func _run_dmg_handler(effect_source: EffectSource) -> void:
	match effect_source.dmg_timeline:
		EffectSource.DmgTimeline.INSTANT:
			$DmgEffectHandler.handle_instant_dmg(effect_source)
		EffectSource.DmgTimeline.OVER_TIME:
			$DmgEffectHandler.handle_over_time_dmg(effect_source)
	_run_stun_handler(effect_source)

## Starts the healing handler based on the healing timeline in the effect source.
func _run_heal_handler(effect_source: EffectSource) -> void:
	match effect_source.heal_timeline:
		EffectSource.HealTimeline.INSTANT:
			$HealEffectHandler.handle_instant_heal(effect_source)
		EffectSource.HealTimeline.OVER_TIME:
			$HealEffectHandler.handle_over_time_heal(effect_source)

## Starts the knockback handler based on what kind of entity the affected entity is.
func _run_knockback_handler(effect_source: EffectSource) -> void:
	if affected_entity is DynamicEntity:
		$KnockbackEffectHandler.handle_dynamic_entity_knockback(effect_source)
	elif affected_entity is RigidEntity:
		$KnockbackEffectHandler.handle_rigid_entity_knockback(effect_source)

## Starts the stun handler, first ensuring there is even any stun to handle.
func _run_stun_handler(effect_source: EffectSource) -> void:
	if has_node("StunEffectHandler"):
		if effect_source.dmg_stun_time > 0:
			$StunEffectHandler.handle_stun(effect_source)

## Checks if the affected entity is on the same team as the producer of the effect source.
func _check_same_team(effect_source: EffectSource) -> bool:
	return team & effect_source.source_team != 0

## Checks if the effect source should damage allies. 
func _check_dmg_allies(effect_source: EffectSource) -> bool:
	return effect_source.dmg_affected_teams & effect_source.DmgAffectedTeams.ALLIES != 0

## Checks if the effect source should damage enemies. 
func _check_dmg_enemies(effect_source: EffectSource) -> bool:
	return effect_source.dmg_affected_teams & effect_source.DmgAffectedTeams.ENEMIES != 0

## Checks if the effect source should heal allies.
func _check_heal_allies(effect_source: EffectSource) -> bool:
	return effect_source.heal_affected_teams & effect_source.HealAffectedTeams.ALLIES != 0

## Checks if the effect source should heal enemies.
func _check_heal_enemies(effect_source: EffectSource) -> bool:
	return effect_source.heal_affected_teams & effect_source.HealAffectedTeams.ENEMIES != 0
