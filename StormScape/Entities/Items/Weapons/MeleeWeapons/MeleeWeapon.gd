@tool
@icon("res://Utilities/Debug/EditorIcons/melee_weapon.png")
extends Weapon
class_name MeleeWeapon
## The base class for all melee weapons. Melee weapons are based on swings and have all needed behavior logic defined here.

enum RECENT_SWING_TYPE { NORMAL, CHARGED }

@export var sprite_visual_rotation: float = 45 ## How rotated the drawn sprite is by default when imported. Straight up would be 0º, angling top-right would be 45º, etc.

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this melee weapon.
@onready var hitbox_component: HitboxComponent = %HitboxComponent ## The hitbox responsible for applying the melee hit.

var is_swinging: bool = false ## Whether we are currently swinging the weapon in some fashion.
var recent_swing_type: RECENT_SWING_TYPE = RECENT_SWING_TYPE.NORMAL ## The most recent type of usage.


## Sets up the base values for the stat mod cache so that weapon mods can be added and managed properly.
static func initialize_stats_resource(stats_resource: MeleeWeaponResource) -> void:
	stats_resource.s_mods = stats_resource.s_mods.duplicate()
	stats_resource.effect_source = stats_resource.effect_source.duplicate()
	stats_resource.charge_effect_source = stats_resource.charge_effect_source.duplicate()
	stats_resource.original_status_effects = stats_resource.effect_source.status_effects.duplicate()
	stats_resource.original_charge_status_effects = stats_resource.charge_effect_source.status_effects.duplicate()

	var normal_moddable_stats: Dictionary[StringName, float] = {
		&"stamina_cost" : stats_resource.stamina_cost,
		&"cooldown" : stats_resource.cooldown,
		&"use_speed" : stats_resource.use_speed,
		&"swing_angle" : stats_resource.swing_angle,
		&"base_damage" : stats_resource.effect_source.base_damage,
		&"base_healing" : stats_resource.effect_source.base_healing,
		&"crit_chance" : stats_resource.effect_source.crit_chance,
		&"armor_penetration" : stats_resource.effect_source.armor_penetration,
		&"pullout_delay" : stats_resource.pullout_delay,
		&"rotation_lerping" : stats_resource.rotation_lerping
	}
	var charge_moddable_stats: Dictionary[StringName, float] = {
		&"min_charge_time" : stats_resource.min_charge_time,
		&"charge_stamina_cost" : stats_resource.charge_stamina_cost,
		&"charge_use_cooldown" : stats_resource.charge_use_cooldown,
		&"charge_use_speed" : stats_resource.charge_use_speed,
		&"charge_swing_angle" : stats_resource.charge_swing_angle,
		&"charge_base_damage" : stats_resource.charge_effect_source.base_damage,
		&"charge_base_healing" : stats_resource.charge_effect_source.base_healing,
		&"charge_crit_chance" : stats_resource.charge_effect_source.crit_chance,
		&"charge_armor_penetration" : stats_resource.charge_effect_source.armor_penetration
	}

	stats_resource.s_mods.add_moddable_stats(normal_moddable_stats)
	stats_resource.s_mods.add_moddable_stats(charge_moddable_stats)

	if stats_resource.weapon_mods_need_to_be_readded_after_save:
		WeaponModManager.reset_original_arrays_after_save(stats_resource, null)
		stats_resource.weapon_mods_need_to_be_readded_after_save = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	super._ready()
	call_deferred("_disable_collider")
	_update_ammo_ui()
	source_entity.stamina_component.stamina_changed.connect(_update_ammo_ui)

	hitbox_component.source_entity = source_entity

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var cooldown_remaining: float = source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id())
	var original_cooldown: float = source_entity.inv.auto_decrementer.get_original_cooldown(stats.get_cooldown_id())
	if cooldown_remaining > 0:
		CursorManager.update_vertical_tint_progress((1 - (cooldown_remaining / original_cooldown)) * 100.0)
	else:
		CursorManager.update_vertical_tint_progress(100.0)

## Disables the hitbox collider for the weapon.
func _disable_collider() -> void:
	hitbox_component.collider.disabled = true

func enter() -> void:
	anim_player.play("MeleeWeaponAnimLibrary/RESET")

	if stats.s_mods.get_stat("pullout_delay") > 0:
		pullout_delay_timer.start(stats.s_mods.get_stat("pullout_delay"))

func exit() -> void:
	super.exit()
	source_entity.facing_component.should_rotate = true

## Overrides the parent method to specify what to do on holding use while equipped.
func hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id()) == 0 or is_swinging:
		source_entity.hands.been_holding_time = 0
		return

	if stats.auto_do_charge_use and stats.can_do_charge_use:
		if (hold_time >= stats.s_mods.get_stat("min_charge_time")):
			_charge_swing()

## Overrides the parent method to specify what to do on release of a holding use while equipped.
func release_hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id()) == 0 or is_swinging:
		source_entity.hands.been_holding_time = 0
		return

	if stats.can_do_charge_use and (hold_time >= stats.s_mods.get_stat("min_charge_time")):
		_charge_swing()
	else:
		_swing()

## Begins the logic for doing a normal weapon swing.
func _swing() -> void:
	if source_entity.stamina_component.use_stamina(stats.s_mods.get_stat("stamina_cost")):
		recent_swing_type = RECENT_SWING_TYPE.NORMAL

		hitbox_component.effect_source = stats.effect_source
		hitbox_component.collision_mask = hitbox_component.effect_source.scanned_phys_layers

		var cooldown_time: float = stats.cooldown + stats.s_mods.get_stat("use_speed")
		source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), cooldown_time)
		is_swinging = true
		source_entity.facing_component.should_rotate = false

		_apply_start_use_effect(false)

		var lib: AnimationLibrary = anim_player.get_animation_library("MeleeWeaponAnimLibrary")
		var anim: Animation = lib.get_animation("use")
		var main_sprite_track: int = anim.find_track("ItemSprite:rotation", Animation.TYPE_VALUE)
		anim.track_set_key_value(main_sprite_track, 1, deg_to_rad(stats.s_mods.get_stat("swing_angle")))

		anim_player.speed_scale = 1.0 / stats.s_mods.get_stat("use_speed")
		anim_player.play("MeleeWeaponAnimLibrary/use")
		if stats.use_sound != "":
			AudioManager.play_sound(stats.use_sound, AudioManager.SoundType.SFX_2D, source_entity.global_position)

## Begins the logic for doing a charged swing.
func _charge_swing() -> void:
	hitbox_component.effect_source = stats.charge_effect_source
	hitbox_component.collision_mask = hitbox_component.effect_source.scanned_phys_layers

	if source_entity.stamina_component.use_stamina(stats.s_mods.get_stat("charge_stamina_cost")):
		recent_swing_type = RECENT_SWING_TYPE.CHARGED

		var cooldown_time: float = stats.s_mods.get_stat("charge_use_cooldown") + stats.s_mods.get_stat("charge_use_speed")
		source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), cooldown_time)
		is_swinging = true
		source_entity.facing_component.should_rotate = false
		source_entity.hands.snap_y_scale()

		_apply_start_use_effect(true)

		var lib: AnimationLibrary = anim_player.get_animation_library("MeleeWeaponAnimLibrary")
		var anim: Animation = lib.get_animation("charge_use")
		var main_sprite_track: int = anim.find_track("ItemSprite:rotation", Animation.TYPE_VALUE)
		anim.track_set_key_value(main_sprite_track, 1, deg_to_rad(stats.s_mods.get_stat("charge_swing_angle")))

		anim_player.speed_scale = 1.0 / stats.s_mods.get_stat("charge_use_speed")
		anim_player.play("MeleeWeaponAnimLibrary/charge_use")
		if stats.charge_use_sound != "":
			AudioManager.play_sound(stats.charge_use_sound, AudioManager.SoundType.SFX_2D, source_entity.global_position)

## Spawns a ghosting effect of the weapon sprite to immitate a fast whoosh.
func _spawn_ghost() -> void:
	var current_anim: String = sprite.animation
	var current_frame: int = sprite.frame
	var sprite_texture: Texture2D = sprite.sprite_frames.get_frame_texture(current_anim, current_frame)

	var adjusted_transform: Transform2D = sprite.global_transform
	var fade_time: float = stats.ghost_fade_time if recent_swing_type != RECENT_SWING_TYPE.CHARGED else stats.charge_ghost_fade_time

	var ghost_instance: SpriteGhost = SpriteGhost.create(adjusted_transform, sprite.scale, sprite_texture, fade_time)
	ghost_instance.flip_h = sprite.flip_h

	if source_entity.hands.current_x_direction != 1:
		ghost_instance.scale = Vector2(1, -1)

	ghost_instance.offset = sprite.offset
	ghost_instance.z_index -= 1
	ghost_instance.make_white()
	Globals.world_root.add_child(ghost_instance)

## Applies a status effect to the source entity at the start of use.
func _apply_start_use_effect(was_charge_fire: bool = false) -> void:
	var effect: StatusEffect = stats.use_start_effect if not was_charge_fire else stats.chg_use_start_effect
	if effect != null:
		source_entity.effect_receiver.handle_status_effect(effect)

## Applies a status effect to the source entity after use.
func _apply_post_use_effect(was_charge_fire: bool = false) -> void:
	var effect: StatusEffect = stats.post_use_effect if not was_charge_fire else stats.post_chg_use_effect
	if effect != null:
		source_entity.effect_receiver.handle_status_effect(effect)

## When the swing animation ends, mark that we are no longer swinging and let the entity rotate again.
func _on_use_animation_ended(was_charge_use: bool = false) -> void:
	is_swinging = false
	source_entity.facing_component.should_rotate = true

	_apply_post_use_effect(was_charge_use)

## If a connected ammo UI exists (i.e. for a player), update it with the new ammo available. Typically just reflects the sprint.
func _update_ammo_ui() -> void:
	if ammo_ui != null: ammo_ui.update_mag_ammo(source_entity.stamina_component.stamina)
