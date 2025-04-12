extends State
class_name DashState
## Handles when the dynamic entity is dashing.

@export var ghost_count: int = 8 ## How many ghosts to make during the dash.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.1 ## How long ghosts take to fade.
@export var dash_impact_cam_fx: CamFXResource

var ghosts_spawned: int = 0 ## The number of ghosts spawned so far in this dash.
var time_since_ghost: float = 0.0 ## The number of seconds since the last ghost spawn.
var collision_shake_complete: bool = false ## Whether the character hit a collider and had shake applied (if player) during the current dash state
var initial_collision_mask: int = 0


func enter() -> void:
	if entity is Player:
		initial_collision_mask = entity.collision_mask
		var bitmask: int = ~((1 << 2) | (1 << 3) | (1 << 4))
		entity.collision_mask &= bitmask

	entity.facing_component.travel_anim_tree("run")

	controller.knockback_vector = Vector2.ZERO
	controller.can_receive_effects = false
	collision_shake_complete = false

	if entity is Player: _play_dash_sound()

	ghosts_spawned = 0
	controller.dash_timer.start(entity.stats.get_stat("dash_duration"))
	controller.dash_cooldown_timer.start(entity.stats.get_stat("dash_duration") + entity.stats.get_stat("dash_cooldown"))
	entity.facing_component.facing_dir = controller.last_facing_dir

	_create_ghost()

func exit() -> void:
	if entity is Player:
		entity.collision_mask = initial_collision_mask

	controller.can_receive_effects = true
	controller.dash_timer.stop()
	entity.velocity = Vector2.ZERO
	controller.knockback_vector = Vector2.ZERO
	if entity is Player: _stop_dash_sound()

## Ticks the time since last ghost spawn.
func state_process(delta: float) -> void:
	time_since_ghost += delta
	_update_ghost_spawns()

func state_physics_process(_delta: float)  -> void:
	_animate()
	_do_character_dash()

## Overrides the dynamic entity's velocity to be a simple dash in the direction currently faced.
func _do_character_dash() -> void:
	entity.velocity = controller.get_movement_vector() * entity.stats.get_stat("dash_speed")
	entity.move_and_slide()

	if entity is Player:
		_handle_rigid_entity_collisions()

## Handles moving rigid entities that we collided with in the last frame. Only happens for players.
func _handle_rigid_entity_collisions() -> void:
	for i: int in entity.get_slide_collision_count():
		var c: KinematicCollision2D = entity.get_slide_collision(i)
		var collider: Object = c.get_collider()

		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal().normalized() * entity.velocity.length() / (5 / (entity.stats.get_stat("dash_collision_impulse_factor"))))
		else:
			return

		if not collision_shake_complete:
			dash_impact_cam_fx.activate_all()
			if entity.effects.check_if_has_effect("kinetic_impact"):
				AudioManager.play_2d("kinetic_impact_hit", entity.global_position)
			else:
				AudioManager.play_2d("player_dash_impact", entity.global_position)

			collision_shake_complete = true

		if i == 0:
			controller.knockback_vector = Vector2.ZERO

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
	add_child(ghost_instance)
	ghosts_spawned += 1

## Plays the dash sound, only for players.
func _play_dash_sound() -> void:
	AudioManager.play_global("player_dash")

## Stops the dash sound, only for players.
func _stop_dash_sound() -> void:
	AudioManager.stop_sound_id("player_dash", 0.1, 1, true)
