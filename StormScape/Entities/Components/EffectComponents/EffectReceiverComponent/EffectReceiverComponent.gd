@icon("res://Utilities/Debug/EditorIcons/effect_receiver_component.svg")
@tool
extends Area2D
class_name EffectReceiverComponent
## A general effect source receiver that passes the appropriate parts of the effect to handlers, but only if
## they exist as children. This node must have an attached collision shape to define where effects are received.
##
## Add specific effect handlers as children of this node to be able to receive those effects on the entity.
## For all intensive purposes, this is acting as a hurtbox component via its receiver area.

@export var can_receive_status_effects: bool = true ## Whether the affected entity can have status effects applied at all. This does not include base damage and base healing. This also determines if the entity can have its stats modded.
@export var absorb_full_hit: bool = false ## When true, any weapon's hitbox that sends an effect to this receiver will be disabled for the remainder of the attack afterwards. Useful for when you want something like a tree to take the full hit and not let an axe keep swinging through to hit enemies behind it.
@export_group("Source Filtering")
@export var filter_source_types: bool = false ## When true, only allow matching source types as specified in the below array.
@export var allowed_source_types: Array[GlobalData.EffectSourceSourceType] = [GlobalData.EffectSourceSourceType.FROM_DEFAULT] ## The list of sources an effect source can come from in order to affect this effect receiver.
@export var filter_source_tags: bool = false ## When true, only allow matching source tags as specified in the below array.
@export var allowed_source_tags: Array[String] = []
@export_group("Connected Nodes")
@export var affected_entity: PhysicsBody2D  ## The connected entity to be affected by the effects be received.
@export var health_component: HealthComponent
@export var stamina_component: StaminaComponent
@export var loot_table_component: LootTableComponent
@export_subgroup("Handlers")
@export var dmg_handler: DmgHandler
@export var heal_handler: HealHandler
@export var storm_syndrome_handler: StormSyndromeHandler
@export var knockback_handler: KnockbackHandler
@export var stun_handler: StunHandler
@export var poison_handler: PoisonHandler
@export var regen_handler: RegenHandler
@export var frostbite_handler: FrostbiteHandler
@export var burning_handler: BurningHandler
@export var time_snare_handler: TimeSnareHandler
@export var life_steal_handler: LifeStealHandler

@onready var tool_script: Node = $EffectReceiverToolScript

var most_recent_effect_src: EffectSource = null
var hit_flash_timer: Timer = Timer.new()
var current_impact_sounds: Array[int] = []


## This works with the tool script defined above to assign export vars automatically in-editor once added to the tree.
func _notification(what: int) -> void:
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
	if can_receive_status_effects: assert(get_parent() is SubViewport or get_parent().has_node("%StatusEffectManager"), get_parent().name + " has an effect receiver flagged as being able to handle status effects, yet has no StatusEffectManager.")

	if not Engine.is_editor_hint():
		collision_layer = affected_entity.collision_layer
		collision_mask = 0
		monitoring = false

		add_child(hit_flash_timer)
		hit_flash_timer.one_shot = true
		hit_flash_timer.wait_time = 0.05
		hit_flash_timer.timeout.connect(_update_hit_flash)
		hit_flash_timer.name = "Hit_Flash_Timer"

## Handles an incoming effect source, passing it to present receivers for further processing before changing
## entity stats.
func handle_effect_source(effect_source: EffectSource, source_entity: PhysicsBody2D, process_status_effects: bool = true) -> void:
	if filter_source_types and (effect_source.source_type not in allowed_source_types):
		return
	if filter_source_tags:
		var match_found: bool = false
		for tag: String in effect_source.source_tags:
			if tag in allowed_source_tags:
				match_found = true
		if not match_found:
			return

	most_recent_effect_src = effect_source

	if source_entity.team == GlobalData.Teams.PASSIVE or ((affected_entity is DynamicEntity) and not affected_entity.move_fsm.can_receive_effects):
		if loot_table_component: loot_table_component.handle_effect_source(effect_source)
		return

	if effect_source.impact_vfx != null:
		var vfx: Node2D = effect_source.impact_vfx.instantiate()
		vfx.global_position = affected_entity.global_position
		add_child(vfx)

	_handle_impact_sound(effect_source)

	_update_hit_flash(effect_source, true)

	_handle_cam_fx(effect_source)

	if effect_source.base_damage > 0 and dmg_handler != null:
		if _check_same_team(source_entity) and _check_if_bad_effects_apply_to_allies(effect_source):
			dmg_handler.handle_instant_damage(effect_source, _get_life_steal(effect_source, source_entity))
			if loot_table_component: loot_table_component.handle_effect_source(effect_source)
		elif not _check_same_team(source_entity) and _check_if_bad_effects_apply_to_enemies(effect_source):
			dmg_handler.handle_instant_damage(effect_source, _get_life_steal(effect_source, source_entity))
			if loot_table_component: loot_table_component.handle_effect_source(effect_source)
	elif loot_table_component and not loot_table_component.require_dmg_on_hit:
		loot_table_component.handle_effect_source(effect_source)

	if effect_source.base_healing > 0 and heal_handler != null:
		if effect_source.base_healing > 0:
			if _check_same_team(source_entity) and _check_if_good_effects_apply_to_allies(effect_source):
				heal_handler.handle_instant_heal(effect_source, effect_source.heal_affected_stats)
			elif not _check_same_team(source_entity) and _check_if_good_effects_apply_to_enemies(effect_source):
				heal_handler.handle_instant_heal(effect_source, effect_source.heal_affected_stats)

	if process_status_effects:
		if can_receive_status_effects:
			if knockback_handler:
				knockback_handler.contact_position = effect_source.contact_position
				knockback_handler.effect_movement_direction = effect_source.movement_direction
				knockback_handler.is_source_moving_type = (effect_source.source_type == GlobalData.EffectSourceSourceType.FROM_PROJECTILE)

			_check_status_effect_team_logic(effect_source, source_entity)

## Checks if each status effect in the array applies to this entity via team logic, then passes it to be unpacked.
func _check_status_effect_team_logic(effect_source: EffectSource, source_entity: PhysicsBody2D) -> void:
	var is_same_team: bool = _check_same_team(source_entity)
	var bad_effects_to_enemies: bool = not is_same_team and _check_if_bad_effects_apply_to_enemies(effect_source)
	var good_effects_to_enemies: bool = not is_same_team and _check_if_good_effects_apply_to_enemies(effect_source)
	var bad_effects_to_allies: bool = is_same_team and _check_if_bad_effects_apply_to_allies(effect_source)
	var good_effects_to_allies: bool = is_same_team and _check_if_good_effects_apply_to_allies(effect_source)

	for status_effect: StatusEffect in effect_source.status_effects:
		if status_effect:
			var applies_to_target: bool = (status_effect.is_bad_effect and (bad_effects_to_enemies or bad_effects_to_allies)) or (not status_effect.is_bad_effect and (good_effects_to_enemies or good_effects_to_allies))

			if applies_to_target:
				handle_status_effect(status_effect)

## Checks for untouchability and handles the stat mods in the status effect.
## Then it passes the effect to have its main logic handled if it needs a handler.
func handle_status_effect(status_effect: StatusEffect) -> void:
	if not _check_if_applicable_entity_type_for_status_effect(status_effect):
		return
	if ("Untouchable" in affected_entity.effects.current_effects) and (status_effect.is_bad_effect):
		return

	for effect_to_stop: String in status_effect.effects_to_stop:
		affected_entity.effects.request_effect_removal(effect_to_stop)

	affected_entity.effects.handle_status_effect(status_effect)
	_pass_effect_to_handler(status_effect)

	if "Untouchable" in affected_entity.effects.current_effects:
		affected_entity.effects.remove_all_bad_status_effects()

## Passes the status effect to a handler if one is needed for additional logic handling.
func _pass_effect_to_handler(status_effect: StatusEffect) -> void:
	if status_effect is StormSyndromeEffect:
		if storm_syndrome_handler: storm_syndrome_handler.handle_storm_syndrome(status_effect)
		else: return
	if status_effect is KnockbackEffect:
		if knockback_handler: knockback_handler.handle_knockback(status_effect)
		else: return
	if status_effect is StunEffect:
		if stun_handler: stun_handler.handle_stun(status_effect)
		else: return
	if status_effect is PoisonEffect:
		if poison_handler: poison_handler.handle_poison(status_effect)
		else: return
	if status_effect is RegenEffect:
		if regen_handler: regen_handler.handle_regen(status_effect)
		else: return
	if status_effect is FrostbiteEffect:
		if frostbite_handler: frostbite_handler.handle_frostbite(status_effect)
		else: return
	if status_effect is BurningEffect:
		if burning_handler: burning_handler.handle_burning(status_effect)
		else: return
	if status_effect is TimeSnareEffect:
		if time_snare_handler: time_snare_handler.handle_time_snare(status_effect)
		else: return

	if not ((affected_entity is not Player) and status_effect.only_cue_on_player_hit):
		if status_effect.audio_to_play != "":
			AudioManager.play_sound(status_effect.audio_to_play, AudioManager.SoundType.SFX_2D, affected_entity.global_position)

## Checks if the affected entity is on the same team as the producer of the effect source.
func _check_same_team(source_entity: PhysicsBody2D) -> bool:
	return affected_entity.team & source_entity.team != 0

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

## Compares the flagged affected entities in the status effect to the type of entity this node is a child of to see if it applies.
func _check_if_applicable_entity_type_for_status_effect(status_effect: StatusEffect) -> bool:
	var class_int: int = 0
	if affected_entity is DynamicEntity:
		class_int = 1
	elif affected_entity is RigidEntity:
		class_int = 2
	elif affected_entity is StaticEntity:
		class_int = 4
	if class_int & status_effect.affected_entities == 0:
		return false
	else:
		return true

## Only plays the impact sound if one exists and one is not already playing for a matching multishot id.
func _handle_impact_sound(effect_source: EffectSource) -> void:
	if effect_source.impact_sound != "":
		var multishot_id: int = effect_source.multishot_id
		if multishot_id != -1:
			if multishot_id not in current_impact_sounds:
				var player: Variant = AudioManager.play_and_get_sound(effect_source.impact_sound, AudioManager.SoundType.SFX_2D, GlobalData.world_root, 0, affected_entity.global_position)
				if player:
					current_impact_sounds.append(multishot_id)

					var callable: Callable = Callable(func() -> void:
						if is_instance_valid(player):
							current_impact_sounds.erase(multishot_id)
						)
					var finish_callables: Variant = player.get_meta("finish_callables")
					finish_callables.append(callable)
					player.set_meta("finish_callables", finish_callables)
		else:
			AudioManager.play_sound(effect_source.impact_sound, AudioManager.SoundType.SFX_2D, affected_entity.global_position)

## Updates whether the hit flash is showing or not. Sets its color to the one specified in the effect source.
func _update_hit_flash(effect_source: EffectSource = null, start: bool = false) -> void:
	if start:
		hit_flash_timer.stop()
		affected_entity.sprite.material.set_shader_parameter("use_override_color", true)
		affected_entity.sprite.material.set_shader_parameter("override_color", effect_source.hit_flash_color)
		hit_flash_timer.start()
	else:
		affected_entity.sprite.material.set_shader_parameter("use_override_color", false)
		affected_entity.sprite.material.set_shader_parameter("override_color", Color(1.0, 1.0, 1.0, 0.0))
	pass

## Starts the player camera fx from the effect source details.
func _handle_cam_fx(effect_source: EffectSource) -> void:
	if effect_source.cam_freeze_duration == 0 and effect_source.cam_shake_duration == 0:
		return

	var is_player: bool = (affected_entity is Player)
	var dist_to_player: float = 0
	var shake_strength: float = effect_source.cam_shake_strength
	var freeze_multiplier: float = effect_source.cam_freeze_multiplier

	dist_to_player = max(0, effect_source.contact_position.distance_to(GlobalData.player_node.global_position) - 16) # Buffer for player's arm distance
	if effect_source.cam_shake_does_falloff: # Can only falloff up to a quarter of the original strength
		shake_strength *= (1 - min(0.25, (dist_to_player / effect_source.cam_shake_max_distance)))
	if dist_to_player > effect_source.cam_shake_max_distance:
		shake_strength = 0
	if effect_source.cam_freeze_does_falloff: # Can only falloff up to a quarter the original multiplier
		freeze_multiplier += min(1.0, min(0.75, (dist_to_player / effect_source.cam_freeze_max_distance)))
	if dist_to_player > effect_source.cam_freeze_max_distance:
		freeze_multiplier = 1.0

	if not (effect_source.cam_shake_on_player_hit_only and not is_player):
		GlobalData.player_camera.start_shake(shake_strength, effect_source.cam_shake_duration)
	if not (effect_source.cam_freeze_on_player_hit_only and not is_player):
		GlobalData.player_camera.start_freeze(freeze_multiplier, effect_source.cam_freeze_duration)

## Checks if there is a life steal effect in the status effects and returns the percent to steal if so.
func _get_life_steal(effect_source: EffectSource, source_entity: PhysicsBody2D) -> float:
	if can_receive_status_effects and life_steal_handler != null:
		for status_effect: StatusEffect in effect_source.status_effects:
			if status_effect is LifeStealEffect:
				life_steal_handler.source_entity = source_entity
				return status_effect.dmg_steal
	return 0.0
