extends State
class_name DashState
## Handles when the dynamic entity is dashing.

@export var ghost_count: int = 8 ## How many ghosts to make during the dash.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.28 ## How long ghosts take to fade.

var dash_impact_cam_fx: CamFXResource = load("res://Entities/Player/PlayerCore/PlayerCamera/CamFXPresets/4(NoFreeze).tres") ## The cam impact to create when a dash hits a collidable entity.
var ghosts_spawned: int = 0 ## The number of ghosts spawned so far in this dash.
var time_since_ghost: float = 0.0 ## The number of seconds since the last ghost spawn.
var collision_shake_complete: bool = false ## Whether the character hit a collider and had shake applied (if player) during the current dash state
var initial_collision_mask: int = 0 ## Saves the pre-dash collision mask so we can restore it on exit (if player).
var active_dash_sound: AudioStreamPlayer2D ## A reference to the active dash sound, if any.


func _init() -> void:
	state_id = "dash"

func enter() -> void:
	# Allowing the player to dash through enemies
	if entity is Player:
		initial_collision_mask = entity.collision_mask
		var bitmask: int = ~((1 << 2) | (1 << 3) | (1 << 4))
		entity.collision_mask &= bitmask

	entity.facing_component.travel_anim_tree("run")

	controller.knockback_vector = Vector2.ZERO
	controller.can_receive_effect_srcs = false
	collision_shake_complete = false

	_play_dash_sound()

	controller.dash_timer.start(entity.stats.get_stat("dash_duration"))
	controller.dash_cooldown_timer.start(entity.stats.get_stat("dash_duration") + entity.stats.get_stat("dash_cooldown"))
	entity.facing_component.facing_dir = controller.last_facing_dir

	ghosts_spawned = 0
	_create_ghost()

func exit() -> void:
	if entity is Player:
		entity.collision_mask = initial_collision_mask

	controller.can_receive_effect_srcs = true
	controller.dash_timer.stop()
	entity.velocity = Vector2.ZERO
	controller.knockback_vector = Vector2.ZERO

	_stop_dash_sound()

func state_process(delta: float) -> void:
	# Ticks the time since last ghost spawn
	time_since_ghost += delta
	_update_ghost_spawns()

func state_physics_process(_delta: float)  -> void:
	_animate()
	_do_character_dash()

## Overrides the dynamic entity's velocity to be a simple dash in the direction currently faced.
func _do_character_dash() -> void:
	entity.velocity = controller.get_movement_vector() * entity.stats.get_stat("dash_speed")
	entity.move_and_slide()

	if StateFunctions.handle_rigid_entity_collisions(entity, controller):
		if not collision_shake_complete:
			dash_impact_cam_fx.activate_all()
			if entity.effects.check_if_has_effect("kinetic_impact"):
				AudioManager.play_2d("kinetic_impact_hit", entity.global_position)
			else:
				AudioManager.play_2d("player_dash_impact", entity.global_position)
			collision_shake_complete = true
	if entity.get_slide_collision_count() > 0:
		_stop_dash_sound()

func _animate() -> void:
	entity.facing_component.update_blend_position("run")

## Checks if we have spent enough time since the last ghost and if we haven't spawned enough yet,
## then spawns one.
func _update_ghost_spawns() -> void:
	if (ghosts_spawned < ghost_count) and (time_since_ghost >= (entity.stats.get_stat("dash_duration") / ghost_count)):
		_create_ghost()
		time_since_ghost = 0.0

## Grabs the current animation frame texture and creates a ghost from it, adding it at the
## proper offset as a child.
func _create_ghost() -> void:
	var sprite_texture: Texture2D = SpriteHelpers.SpriteDetails.get_frame_texture(entity.sprite)

	var ghost_pos: Vector2 = Vector2(entity.position.x + entity.sprite.position.x, entity.position.y + entity.sprite.position.y)
	var ghost_transform: Transform2D = Transform2D(entity.rotation, ghost_pos)

	var ghost_instance: SpriteGhost = SpriteGhost.create(ghost_transform, entity.scale, sprite_texture, ghost_fade_time)
	controller.add_child(ghost_instance)
	ghosts_spawned += 1

func _play_dash_sound() -> void:
	if not AudioManager.is_player_valid(active_dash_sound):
		active_dash_sound = AudioManager.play_2d("player_dash", entity.global_position, 0, fsm)

func _stop_dash_sound() -> void:
	if AudioManager.is_player_valid(active_dash_sound):
		AudioManager.stop_audio_player(active_dash_sound, 0.1, true)
