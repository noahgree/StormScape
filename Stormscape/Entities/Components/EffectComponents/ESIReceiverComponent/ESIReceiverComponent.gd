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

@export var can_be_crit: bool = true ## When false, critical hits are impossible on this entity.
@export var absorb_full_hit: bool = false ## When true, any weapon's hitbox that sends an effect to this receiver will be disabled for the remainder of the attack afterwards. Useful for when you want something like a tree to take the full hit and not let an axe keep swinging through to hit enemies behind it.
@export_group("Source Filtering")
@export var filter_source_types: bool = false ## When true, only allow matching source types as specified in the below array.
@export var allowed_source_types: Array[Globals.ESISourceType] = [] ## The list of sources an effect source can come from in order to affect this esi receiver (only when filter_source_types is true).
@export var filter_source_tags: bool = false ## When true, only allow matching source tags as specified in the below array.
@export var allowed_source_tags: Array[String] = [] ## Effect sources must have a tag that matches something in this array in order to be handled when the filter_source_tags is set to true.
@export_group("Entity Stat Modifiers")
@export var stat_modifiers: EntityStatModifiers = EntityStatModifiers.new()

@onready var entity: Entity = owner ## The owning entity to be affected by the ESIs being received.
@onready var dh_handler: DHHandler = %DHHandler ## The dh handler child.

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

	stat_modifiers.initialize_stat_cache(entity)

## Handles an incoming effect source, passing it to present receivers for further processing before changing
## entity stats.
func handle_esi(esi: ESI, process_conditions: bool = true) -> void:
	# --- Applying Cam FX & Hit Sound ---
	_handle_cam_fx(esi)
	_handle_impact_sound(esi)

	# --- Changing Cursor to Reflect Hit ---
	if (esi.source_entity) and (esi.source_entity is Player) and (not entity is Player):
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

	# --- Spawning Impact VFX ---
	if esi.es.impact_vfx != null:
		var vfx: Node2D = esi.es.impact_vfx.instantiate()
		vfx.global_position = entity.global_position
		add_child(vfx)

	# --- Checking Invulnerability ---
	if entity.invulnerable:
		return

	# --- Checking if We Should Drop Loot on Hit Early and Return ---
	if (esi.source_entity) and (esi.source_entity_team == Globals.Teams.PASSIVE):
		if (esi.es.source_type != Globals.ESISourceType.FROM_EOTI) and (entity.loot):
			entity.loot.handle_hit()
		return

	# --- Triggering Loot Component if not from EOTI ---
	if (entity.loot) and (not entity.loot.require_dmg_on_hit):
		if esi.es.source_type != Globals.ESISourceType.FROM_EOTI:
			entity.loot.handle_hit()

	# --- Applying Base Damage & Base Healing ---
	var xp: int = 0

	if EffectSource.can_hit_ally_with_bad(entity.team, esi.source_entity_team, esi.es):
		dh_handler.handle_instant_amount(DHHandler.Type.DAMAGE, HPComponent.POPUP_TYPE.AUTO, esi)
	elif EffectSource.can_hit_enemy_with_bad(entity.team, esi.source_entity_team, esi.es):
		xp = dh_handler.handle_instant_amount(DHHandler.Type.DAMAGE, HPComponent.POPUP_TYPE.AUTO, esi)

	if EffectSource.can_hit_ally_with_good(entity.team, esi.source_entity_team, esi.es):
		xp = dh_handler.handle_instant_amount(DHHandler.Type.HEALING, HPComponent.POPUP_TYPE.AUTO, esi)
	elif EffectSource.can_hit_enemy_with_good(entity.team, esi.source_entity_team, esi.es):
		dh_handler.handle_instant_amount(DHHandler.Type.HEALING, HPComponent.POPUP_TYPE.AUTO, esi)

	# --- Applying Resulting Weapon XP ---
	if (esi.source_entity) and (esi.source_entity is Player) and (esi.source_ii):
		esi.source_ii.add_xp(ceili(WeaponII.EFFECT_AMOUNT_XP_MULT * xp))

	# --- Start of Status Effect Processing Chain ---
	if process_conditions and can_receive_conditions:
		if (esi.multishot_id == -1) or (esi.multishot_id != most_recent_multishot_id):
			most_recent_multishot_id = esi.multishot_id

			if knockback_handler:
				knockback_handler.contact_position = esi.contact_position
				knockback_handler.effect_movement_direction = esi.movement_direction
				knockback_handler.is_source_moving_type = (esi.es.source_type == Globals.ESISourceType.FROM_PROJECTILE)

			_check_condition_team_logic(esi)

## Checks if each condition in the array applies to this entity via team logic, then passes it to be unpacked.
func _check_condition_team_logic(esi: ESI) -> void:
	var is_same_team: bool = _check_same_team(esi.source_entity_team)
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
	if not _check_if_applicable_entity_type_for_condition(condition) or entity.invulnerable:
		return
	if (entity.effects.is_untouchable()) and (condition.is_bad_effect):
		return

	for effect_to_stop: Condition.ID in condition.effects_to_stop:
		entity.effects.request_effect_removal_for_all_sources(effect_to_stop)

	entity.effects.handle_condition(condition)
	_pass_effect_to_handler(condition)

	if entity.conditions_component.is_untouchable():
		entity.conditions_component.remove_all_bad_conditions()

## Passes the condition to a handler if one is needed for additional logic handling.
func _pass_effect_to_handler(condition: Condition) -> void:
	#if condition is KnockbackStats:
		#if knockback_handler: knockback_handler.handle_knockback(condition)
		#else: return
	#if condition is StunEffect:
		#if stun_handler: stun_handler.handle_stun(condition)
		#else: return
	#if condition is TimeSnareEffect:
		#if time_snare_handler: time_snare_handler.handle_time_snare(condition)
		#else: return

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

#region Debug
### Attempts to apply a condition based on its file name turned into snake case. "poison_1", for example.
#func apply_condition_by_id(effect_key: StringName) -> void:
	#var condition: Condition = ConditionsComponent.cache.get(effect_key, null)
	#if condition == null:
		#printerr("The request to apply the condition \"" + effect_key + "\" failed because it does not exist.")
		#return
#
	#handle_condition(condition)
#
### Attempts to remove a condition based on its condition id. "poison", for example.
#func remove_all_conditions_of_id(effect_id: StringName) -> void:
	#entity.effects.request_condition_removal_for_all_sources(effect_id)
#
### Attempts to remove a condition based on its condition id case plus its source.
### "poison:from_weapon", for example.
#func remove_condition_by_id_and_source(effect_key: StringName) -> void:
	#if effect_key not in entity.effects.current_effects:
		#printerr("The request to remove \"" + effect_key + "\" failed because it does not exist as a currently applied condition.")
		#return
#
	#var effect_pieces: PackedStringArray = effect_key.split(":")
	#if effect_pieces.size() < 2:
		#return
	#entity.effects.request_effect_removal_by_source_string(effect_pieces[0], effect_pieces[1])
#endregion
