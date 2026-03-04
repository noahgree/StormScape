@icon("res://Utilities/Debug/EditorIcons/effect_receiver_component.svg")
@tool
extends Area2D
class_name ESIReceiverComponent
## A general ESI receiver that passes the appropriate parts of the effect to handlers, but only if
## they exist as children. This node must have an attached collision shape to define where effects are received.
## This node's collision also determines what part of this entity must enter the DetectionComponent
## of another entity before we know about that entity's presence.
##
## Add specific effect handlers as children of this node to be able to receive those effects on the entity.
## For all intensive purposes, this is acting as a hurtbox component via its receiver area.

@export var can_receive_conditions: bool = true ## Whether the affected entity can have conditions applied at all. This does not include base damage and base healing. This also determines if the entity can have its stats modded.
@export var absorb_full_hit: bool = false ## When true, any weapon's hitbox that sends an effect to this receiver will be disabled for the remainder of the attack afterwards. Useful for when you want something like a tree to take the full hit and not let an axe keep swinging through to hit enemies behind it.
@export_group("Source Filtering")
@export var filter_source_types: bool = false ## When true, only allow matching source types as specified in the below array.
@export var allowed_source_types: Array[Globals.ESISourceType] = [] ## The list of sources an effect source can come from in order to affect this esi receiver (only when filter_source_types is true).
@export var filter_source_tags: bool = false ## When true, only allow matching source tags as specified in the below array.
@export var allowed_source_tags: Array[String] = [] ## Effect sources must have a tag that matches something in this array in order to be handled when the filter_source_tags is set to true.
@export_group("Connected Nodes")
@export var entity: Entity  ## The connected entity to be affected by the effects be received.
@export var dh_handler: DHHandler ## The dmg handler of the affected entity.
@export var heal_handler: HealHandler ## The heal handler of the affected entity.
@export_group("Effect Handlers")
@export var storm_syndrome_handler: StormSyndromeHandler ## The storm syndrome of the affected entity.
@export var knockback_handler: KnockbackHandler ## The knockback of the affected entity.
@export var stun_handler: StunHandler ## The stun handler of the affected entity.
@export var poison_handler: PoisonHandler ## The poison handler of the affected entity.
@export var regen_handler: RegenHandler ## The regen handler of the affected entity.
@export var frostbite_handler: FrostbiteHandler ## The frostbite handler of the affected entity.
@export var burning_handler: BurningHandler ## The burning handler of the affected entity.
@export var time_snare_handler: TimeSnareHandler ## The time snare handler of the affected entity.
@export var life_steal_handler: LifeStealHandler ## The life steal handler of the affected entity.

@onready var tool_script: RefCounted = load("res://Entities/Components/EffectComponents/ESIReceiverComponent/ESIReceiverTool.gd").new(self) ## The tool script node that helps auto-assign export nodes relative to this receiver.

var current_impact_sounds: Array[int] = [] ## The current impact sounds being played and held onto by this esi receiver.
var most_recent_multishot_id: int = 0 ## The most recent multishot id to be received. Prevents multishots from stacking conditions.


## Asserts that the affected entity has been set for easy debugging, then sets the monitoring to off for
## performance reasons in case it was changed in the editor. It also ensures the collision layer is the same as the
## affected entity so that the effect sources only see it when they should.
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not entity.is_node_ready():
		await entity.ready

	collision_layer = entity.collision_layer
	collision_mask = 0
	monitoring = false

## Handles an incoming effect source, passing it to present receivers for further processing before changing
## entity stats.
func handle_esi(esi: ESI, source_entity: Entity, source_ii: WeaponII, process_conditions: bool = true) -> void:
	# --- Applying Cam FX & Hit Sound ----
	_handle_cam_fx(esi)
	_handle_impact_sound(esi)

	# --- Changing Cursor to Reflect Hit ---
	if source_entity and source_entity is Player and not entity is Player:
		CursorManager.change_cursor(null, "hit")

	# --- Filtering Source Types & Tags ---
	if filter_source_types and (esi.es.source_type not in allowed_source_types):
		return
	if filter_source_tags:
		var match_found: bool = false
		for tag: String in esi.es.source_tags:
			if tag in allowed_source_tags:
				match_found = true
		if not match_found:
			return

	# --- Checking if Sender is Passive or Receiver Can't Receive Effect Sources ---
	if (source_entity and source_entity.team == Globals.Teams.PASSIVE) or not _check_if_can_receive_effect_sources_and_conditions():
		if entity.loot:
			entity.loot.handle_hit()
		return

	# --- Spawning Impact VFX ---
	if esi.es.impact_vfx != null:
		var vfx: Node2D = esi.es.impact_vfx.instantiate()
		vfx.global_position = entity.global_position
		add_child(vfx)

	# --- Validating Source Entity ---
	if not source_entity:
		return

	# --- Triggering Loot Component ---
	if entity.loot and not entity.loot.require_dmg_on_hit:
		entity.loot.handle_hit()

	# --- Applying Base Damage & Base Healing ---
	var xp: int = 0
	var do_hitflash: bool = false
	var source_level: int = source_ii.level if source_ii else 1
	if esi.get_stat(&"base_damage") > 0 and dh_handler != null:
		if _check_same_team(source_entity) and _check_if_bad_effects_apply_to_allies(esi.es):
			dh_handler.handle_instant_damage(esi, source_level, _get_life_steal(esi, source_entity))
			do_hitflash = true
		elif not _check_same_team(source_entity) and _check_if_bad_effects_apply_to_enemies(esi.es):
			xp = dh_handler.handle_instant_damage(esi, source_level, _get_life_steal(esi, source_entity))
			do_hitflash = true

	if esi.get_stat(&"base_healing") > 0 and heal_handler != null:
		if _check_same_team(source_entity) and _check_if_good_effects_apply_to_allies(esi.es):
			xp = heal_handler.handle_instant_heal(esi, source_level)
			do_hitflash = true
		elif not _check_same_team(source_entity) and _check_if_good_effects_apply_to_enemies(esi.es):
			heal_handler.handle_instant_heal(esi, source_level)
			do_hitflash = true

	if do_hitflash:
		entity.sprite.start_hitflash(esi.es.hit_flash_color, false)

	# --- Applying Resulting Weapon XP ---
	if source_entity is Player and source_ii and is_instance_valid(source_ii):
		var xp_to_add: int = ceili(WeaponII.EFFECT_AMOUNT_XP_MULT * xp)
		source_ii.add_xp(xp_to_add)

	# --- Start of Status Effect Processing Chain ---
	if process_conditions:
		if can_receive_conditions:
			if (esi.multishot_id == -1) or (esi.multishot_id != most_recent_multishot_id):
				most_recent_multishot_id = esi.multishot_id

				if knockback_handler:
					knockback_handler.contact_position = esi.contact_position
					knockback_handler.effect_movement_direction = esi.movement_direction
					knockback_handler.is_source_moving_type = (esi.es.source_type == Globals.ESISourceType.FROM_PROJECTILE)

				_check_condition_team_logic(esi, source_entity)

## Checks if each condition in the array applies to this entity via team logic, then passes it to be unpacked.
func _check_condition_team_logic(esi: ESI, source_entity: Entity) -> void:
	var is_same_team: bool = _check_same_team(source_entity)
	var bad_effects_to_enemies: bool = not is_same_team and _check_if_bad_effects_apply_to_enemies(esi.es)
	var good_effects_to_enemies: bool = not is_same_team and _check_if_good_effects_apply_to_enemies(esi.es)
	var bad_effects_to_allies: bool = is_same_team and _check_if_bad_effects_apply_to_allies(esi.es)
	var good_effects_to_allies: bool = is_same_team and _check_if_good_effects_apply_to_allies(esi.es)

	for condition: Condition in esi.conditions:
		if condition:
			var applies_to_target: bool = (condition.is_bad_effect and (bad_effects_to_enemies or bad_effects_to_allies)) or (not condition.is_bad_effect and (good_effects_to_enemies or good_effects_to_allies))

			if applies_to_target:
				handle_condition(condition)

## Checks for untouchability and handles the stat mods in the condition.
## Then it passes the effect to have its main logic handled if it needs a handler.
func handle_condition(condition: Condition) -> void:
	if not _check_if_applicable_entity_type_for_condition(condition) or not _check_if_can_receive_effect_sources_and_conditions():
		return
	if (entity.effects.is_untouchable()) and (condition.is_bad_effect):
		return

	for effect_to_stop: Condition.ID in condition.effects_to_stop:
		entity.effects.request_effect_removal_for_all_sources(effect_to_stop)

	entity.effects.handle_condition(condition)
	_pass_effect_to_handler(condition)

	if entity.effects.is_untouchable():
		entity.effects.remove_all_bad_conditions()

## Passes the condition to a handler if one is needed for additional logic handling.
func _pass_effect_to_handler(condition: Condition) -> void:
	if condition is StormSyndromeEffect:
		if storm_syndrome_handler: storm_syndrome_handler.handle_storm_syndrome(condition)
		else: return
	if condition is KnockbackEffect:
		if knockback_handler: knockback_handler.handle_knockback(condition)
		else: return
	if condition is StunEffect:
		if stun_handler: stun_handler.handle_stun(condition)
		else: return
	if condition is PoisonEffect:
		if poison_handler: poison_handler.handle_poison(condition)
		else: return
	if condition is RegenEffect:
		if regen_handler: regen_handler.handle_regen(condition)
		else: return
	if condition is FrostbiteEffect:
		if frostbite_handler: frostbite_handler.handle_frostbite(condition)
		else: return
	if condition is BurningEffect:
		if burning_handler: burning_handler.handle_burning(condition)
		else: return
	if condition is TimeSnareEffect:
		if time_snare_handler: time_snare_handler.handle_time_snare(condition)
		else: return

	if not ((entity is not Player) and condition.only_cue_on_player_hit):
		AudioManager.play_2d(condition.audio_to_play, entity.global_position)

## Checks if the affected entity is on the same team as the producer of the effect source.
func _check_same_team(source_entity: Entity) -> bool:
	return entity.team & source_entity.team != 0

## Checks if the effect source should do bad effects to allies.
func _check_if_bad_effects_apply_to_allies(effect_source: EffectSource) -> bool:
	return effect_source.bad_effect_affected_teams & Globals.BadEffectAffectedTeams.ALLIES != 0

## Checks if the effect source should do bad effects to enemies.
func _check_if_bad_effects_apply_to_enemies(effect_source: EffectSource) -> bool:
	return effect_source.bad_effect_affected_teams & Globals.BadEffectAffectedTeams.ENEMIES != 0

## Checks if the effect source should do good effects to allies.
func _check_if_good_effects_apply_to_allies(effect_source: EffectSource) -> bool:
	return effect_source.good_effect_affected_teams & Globals.GoodEffectAffectedTeams.ALLIES != 0

## Checks if the effect source should do good effects to enemies.
func _check_if_good_effects_apply_to_enemies(effect_source: EffectSource) -> bool:
	return effect_source.good_effect_affected_teams & Globals.GoodEffectAffectedTeams.ENEMIES != 0

## Compares the flagged affected entities in the condition to the type of entity
## this node is a child of to see if it applies.
func _check_if_applicable_entity_type_for_condition(condition: Condition) -> bool:
	var class_int: int = 0
	if entity is DynamicEntity:
		class_int = 1
	elif entity is RigidEntity:
		class_int = 2
	elif entity is StaticEntity:
		class_int = 4
	if class_int & condition.affected_entities == 0:
		return false
	else:
		return true

## Checks if the affected entity is Dynamic and has been flagged to not receieve effect sources (and therefore
## not conditions, either).
func _check_if_can_receive_effect_sources_and_conditions() -> bool:
	if (entity is DynamicEntity) and not entity.fsm.controller.can_receive_effect_srcs:
		return false
	elif not can_receive_conditions:
		return false
	return true

## Only plays the impact sound if one exists and one is not already playing for a matching multishot id.
func _handle_impact_sound(esi: ESI) -> void:
	var multishot_id: int = esi.multishot_id
	if multishot_id != -1:
		if multishot_id not in current_impact_sounds:
			var player_inst: AudioPlayerInstance = AudioManager.play_2d(esi.es.impact_sound, entity.global_position, 0, true, -1, Globals.world_root)
			if player_inst:
				current_impact_sounds.append(multishot_id)

				var callable: Callable = Callable(func() -> void: current_impact_sounds.erase(multishot_id))
				AudioManager.add_finish_callable_to_player(player_inst.player, callable)
	else:
		AudioManager.play_2d(esi.es.impact_sound, entity.global_position, 0, true)

## Starts the player camera fx from the effect source details.
func _handle_cam_fx(esi: ESI) -> void:
	if esi.es.impact_cam_fx == null:
		return
	esi.es.impact_cam_fx.apply_falloffs_and_activate_all(entity)

## Checks if there is a life steal effect in the conditions and returns the percent to steal if so.
func _get_life_steal(esi: ESI, source_entity: Entity) -> float:
	if can_receive_conditions and life_steal_handler:
		for condition: Condition in esi.conditions:
			if condition is LifeStealEffect:
				life_steal_handler.source_entity = source_entity
				return condition.dmg_steal
	return 0.0

#region Debug
## This works with the tool script defined above to assign export vars automatically in-editor once added
## to the tree.
func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if tool_script and what == NOTIFICATION_EDITOR_PRE_SAVE:
			tool_script.update_editor_children_exports(self, get_children())
			tool_script.update_editor_parent_export(self, get_parent())
			tool_script.ensure_effect_handler_resource_unique_to_scene(self)

## Edits editor warnings for easier debugging.
func _get_configuration_warnings() -> PackedStringArray:
	if can_receive_conditions and not get_parent().has_node("%ConditionsComponent"):
		return [
			"Entities with ESI receievers marked as being able to receive conditions must have a ConditionsComponent. Make sure it has a unique name (%)."
			]
	return []

## Attempts to apply a condition based on its file name turned into snake case. "poison_1", for example.
func apply_condition_by_id(effect_key: StringName) -> void:
	var condition: Condition = ConditionsComponent.cache.get(effect_key, null)
	if condition == null:
		printerr("The request to apply the condition \"" + effect_key + "\" failed because it does not exist.")
		return

	handle_condition(condition)

## Attempts to remove a condition based on its condition id. "poison", for example.
func remove_all_conditions_of_id(effect_id: StringName) -> void:
	entity.effects.request_condition_removal_for_all_sources(effect_id)

## Attempts to remove a condition based on its condition id case plus its source.
## "poison:from_weapon", for example.
func remove_condition_by_id_and_source(effect_key: StringName) -> void:
	if effect_key not in entity.effects.current_effects:
		printerr("The request to remove \"" + effect_key + "\" failed because it does not exist as a currently applied condition.")
		return

	var effect_pieces: PackedStringArray = effect_key.split(":")
	if effect_pieces.size() < 2:
		return
	entity.effects.request_effect_removal_by_source_string(effect_pieces[0], effect_pieces[1])
#endregion
