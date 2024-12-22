extends Weapon
class_name MeleeWeapon
## The base class for all melee weapons. Melee weapons are based on swings and have all needed behavior logic defined here.

@export var sprite_visual_rotation: float = 45 ## How rotated the drawn sprite is by default when imported. Straight up would be 0º, angling top-right would be 45º, etc.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.25 ## How long ghosts take to fade.

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this melee weapon.
@onready var hitbox_component: HitboxComponent = %HitboxComponent ## The hitbox responsible for applying the melee hit.

var is_swinging: bool = false ## Whether we are currently swinging the weapon in some fashion.
var is_holding: bool = false ## Whether we are holding down the trigger so as to potentially charge up a charge swing.
const HOLDING_THRESHOLD: float = 0.1 ## How long a hold press must be to start tracking a potential charge up.


#region Saving & Loading
func _on_load_game() -> void:
	if not cache_is_setup_after_load:
		_setup_mod_cache()

	for mod: WeaponMod in stats.current_mods.values():
		weapon_mod_manager._add_weapon_mod(mod)
#endregion

func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)

	# Duplicates the cache & effect sources to be unique and then calls for the cache to get loaded.
	if not stats.cache_is_setup:
		stats.s_mods = stats.s_mods.duplicate()
		stats.effect_source = stats.effect_source.duplicate()
		stats.charge_effect_source = stats.charge_effect_source.duplicate()
		stats.original_status_effects = stats.effect_source.status_effects.duplicate()
		stats.original_charge_status_effects = stats.charge_effect_source.status_effects.duplicate()
		_setup_mod_cache()

	if hitbox_component:
		hitbox_component.effect_source = stats.effect_source
		hitbox_component.collision_mask = hitbox_component.effect_source.scanned_phys_layers

## Sets up the base values for the stat mod cache so that weapon mods can be added and managed properly.
func _setup_mod_cache() -> void:
	var normal_moddable_stats: Dictionary = {
		"stamina_cost" : stats.stamina_cost,
		"cooldown" : stats.cooldown,
		"use_speed" : stats.use_speed,
		"swing_angle" : stats.swing_angle,
		"base_damage" : stats.effect_source.base_damage,
		"base_healing" : stats.effect_source.base_healing,
		"crit_chance" : stats.effect_source.crit_chance,
		"armor_penetration" : stats.effect_source.armor_penetration,
		"pullout_delay" : stats.pullout_delay
	}
	var charge_moddable_stats: Dictionary = {
		"min_charge_time" : stats.min_charge_time,
		"charge_stamina_cost" : stats.charge_stamina_cost,
		"charge_use_cooldown" : stats.charge_use_cooldown,
		"charge_use_speed" : stats.charge_use_speed,
		"charge_swing_angle" : stats.charge_swing_angle,
		"charge_base_damage" : stats.charge_effect_source.base_damage,
		"charge_base_healing" : stats.charge_effect_source.base_healing,
		"charge_crit_chance" : stats.charge_effect_source.crit_chance,
		"charge_armor_penetration" : stats.charge_effect_source.armor_penetration
	}

	stats.s_mods.add_moddable_stats(normal_moddable_stats)
	stats.s_mods.add_moddable_stats(charge_moddable_stats)
	stats.cache_is_setup = true

func _ready() -> void:
	super._ready()
	call_deferred("_disable_collider")
	_update_ammo_ui()
	source_entity.stamina_component.stamina_changed.connect(_update_ammo_ui)

	hitbox_component.source_entity = source_entity

## Disables the hitbox collider for the weapon.
func _disable_collider() -> void:
	hitbox_component.collider.disabled = true

func enter() -> void:
	if stats.s_mods.base_values.is_empty():
		_setup_mod_cache()
		cache_is_setup_after_load = true

func exit() -> void:
	source_entity.move_fsm.should_rotate = true

## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	if is_swinging:
		return

	is_holding = false
	await get_tree().create_timer(HOLDING_THRESHOLD, false, false, false).timeout
	if not is_holding or not stats.can_do_charge_use:
		if pullout_delay_timer.is_stopped() and source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id()) == 0:
			if not source_entity.hands.scale_is_lerping:
				_swing()

## Overrides the parent method to specify what to do on holding use while equipped.
func hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id()) == 0 or is_swinging:
		source_entity.hands.been_holding_time = 0
		return

	if hold_time >= HOLDING_THRESHOLD:
		is_holding = true
		if stats.auto_do_charge_use and stats.can_do_charge_use:
			_charge_swing(hold_time)

## Overrides the parent method to specify what to do on release of a holding use while equipped.
func release_hold_activate(hold_time: float) -> void:
	if not pullout_delay_timer.is_stopped() or not source_entity.inv.auto_decrementer.get_cooldown(stats.get_cooldown_id()) == 0 or is_swinging:
		source_entity.hands.been_holding_time = 0
		return

	if hold_time >= HOLDING_THRESHOLD and not stats.auto_do_charge_use and stats.can_do_charge_use:
		_charge_swing(hold_time)

## Begins the logic for doing a normal weapon swing.
func _swing() -> void:
	if source_entity.stamina_component.use_stamina(stats.s_mods.get_stat("stamina_cost")):
		var cooldown_time: float = stats.cooldown + stats.s_mods.get_stat("use_speed")
		source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), cooldown_time)
		is_swinging = true
		source_entity.move_fsm.should_rotate = false

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
func _charge_swing(hold_time: float) -> void:
	if not (hold_time >= stats.s_mods.get_stat("min_charge_time")):
		return

	if source_entity.stamina_component.use_stamina(stats.s_mods.get_stat("charge_stamina_cost")):
		var cooldown_time: float = stats.s_mods.get_stat("charge_use_cooldown") + stats.s_mods.get_stat("charge_use_speed")
		source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), cooldown_time)
		is_swinging = true
		source_entity.move_fsm.should_rotate = false
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

	var adjusted_transform: Transform2D = sprite.transform
	var rotated_offset: Vector2 = sprite.offset.rotated(sprite.rotation)
	adjusted_transform.origin += rotated_offset

	var ghost_instance: SpriteGhost = SpriteGhost.create(adjusted_transform, sprite.scale, sprite_texture, ghost_fade_time)
	ghost_instance.flip_h = sprite.flip_h
	ghost_instance.make_white()
	add_child(ghost_instance)

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
	source_entity.move_fsm.should_rotate = true

	_apply_post_use_effect(was_charge_use)

## If a connected ammo UI exists (i.e. for a player), update it with the new ammo available. Typically just reflects the sprint.
func _update_ammo_ui() -> void:
	if ammo_ui != null: ammo_ui.update_mag_ammo(source_entity.stamina_component.stamina)
