extends MoveState
## Handles when the character is dashing.

@export var _dash_speed: float = 1000 ## How fast the dash moves the character.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _dash_duration: float = 0.08 ## The dash duration.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _dash_cooldown: float = 1.0 ## The dash cooldown.
@export var _dash_collision_impulse_factor: float = 1.0 ## A multiplier that controls how much impulse gets applied to rigid entites when colliding with them during a dash.
@export var ghost_scene: PackedScene = load("res://Entities/EntityCore/SpriteGhost.tscn") ## The scene that defines the ghosts' behavior.
@export var ghost_count: int = 8 ## How many ghosts to make during the dash.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.1 ## How long ghosts take to fade.

@onready var dash_timer: Timer = $DashTimer ## Timer to enforce how long the dash lasts for.

var movement_vector: Vector2 = Vector2.ZERO ## The current direction of movement.
var ghosts_spawned: int = 0 ## The number of ghosts spawned so far in this dash.
var time_since_ghost: float = 0.0 ## The number of seconds since the last ghost spawn.
var can_spawn_ghosts: bool = false ## Whether we have the proper node to enable ghost spawns during dash.
var parent_sprite_node: Node2D
var collision_shake_complete: bool = false ## Whether the character hit a collider and had shake applied (if player) during the current dash state


func _ready() -> void:
	var moddable_stats: Dictionary = {
		"dash_speed" : _dash_speed, "dash_duration" : _dash_duration,
		"dash_cooldown" : _dash_cooldown, "dash_collision_impulse_factor" : _dash_collision_impulse_factor
	}
	get_parent().entity.stats.add_moddable_stats(moddable_stats)

func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("run")
	fsm.knockback_vector = Vector2.ZERO
	fsm.can_receive_effects = false
	collision_shake_complete = false
	_play_dash_sound()

	ghosts_spawned = 0
	dash_timer.start(dynamic_entity.stats.get_stat("dash_duration"))
	fsm.dash_cooldown_timer.start(dynamic_entity.stats.get_stat("dash_duration") + dynamic_entity.stats.get_stat("dash_cooldown"))
	movement_vector = _calculate_move_vector()
	fsm.anim_vector = get_parent().curr_mouse_direction

	if dynamic_entity.has_node("AnimatedSprite2D"):
		parent_sprite_node = dynamic_entity.get_node("AnimatedSprite2D")
	elif dynamic_entity.has_node("Sprite2D"):
		parent_sprite_node = dynamic_entity.get_node("Sprite2D")
	else:
		return
	_create_ghost()
	can_spawn_ghosts = true

func exit() -> void:
	fsm.can_receive_effects = true
	dash_timer.stop()
	dynamic_entity.velocity = Vector2.ZERO
	fsm.knockback_vector = Vector2.ZERO
	_stop_dash_sound()

## Ticks the time since last ghost spawn.
func state_process(delta: float) -> void:
	if can_spawn_ghosts:
		time_since_ghost += delta
		_update_ghost_spawns()

func state_physics_process(_delta: float)  -> void:
	_animate()
	_do_character_dash()

## Overrides the dynamic entity's velocity to be a simple dash in the direction currently faced.
func _do_character_dash() -> void:
	dynamic_entity.velocity = movement_vector * dynamic_entity.stats.get_stat("dash_speed")
	dynamic_entity.move_and_slide()

	# handle collisions with rigid entities
	for i in dynamic_entity.get_slide_collision_count():
		var c = dynamic_entity.get_slide_collision(i)
		var collider = c.get_collider()
		if collider is RigidEntity:
			collider.apply_central_impulse(-c.get_normal().normalized() * dynamic_entity.velocity.length() / (5 / (dynamic_entity.stats.get_stat("dash_collision_impulse_factor"))))
			if not collision_shake_complete:
				GlobalData.player_camera.start_shake(2.2, 0.15)
				if dynamic_entity.effects.check_if_has_effect("KineticImpact"):
					AudioManager.play_sound("KineticImpactHit", AudioManager.SoundType.SFX_2D, dynamic_entity.global_position)
				else:
					AudioManager.play_sound("PlayerDashImpact", AudioManager.SoundType.SFX_2D, dynamic_entity.global_position)
				collision_shake_complete = true

func _calculate_move_vector() -> Vector2:
	return (_get_input_vector().rotated(dynamic_entity.stats.get_stat("confusion_amount")))

func _animate() -> void:
	fsm.anim_tree.set("parameters/run/blendspace2d/blend_position", fsm.anim_vector)

## Checks if we have spent enough time since the last ghost and if we haven't spawned enough yet, then spawns one.
func _update_ghost_spawns() -> void:
	if (ghosts_spawned < ghost_count) and (time_since_ghost >= (dynamic_entity.stats.get_stat("dash_duration") / ghost_count)):
		_create_ghost()
		time_since_ghost = 0.0

## Grabs the current animation frame texture and creates a ghost from it, adding it at the proper offset as a child.
func _create_ghost() -> void:
	var sprite_texture: Texture2D
	if parent_sprite_node is AnimatedSprite2D:
		var animated_sprite_node = dynamic_entity.get_node("AnimatedSprite2D")
		var current_anim: String = animated_sprite_node.animation
		var current_frame: int = animated_sprite_node.frame
		sprite_texture = animated_sprite_node.sprite_frames.get_frame_texture(current_anim, current_frame)
	elif parent_sprite_node is Sprite2D:
		sprite_texture = parent_sprite_node.texture

	var ghost_pos: Vector2 = Vector2(dynamic_entity.position.x + parent_sprite_node.position.x, dynamic_entity.position.y + parent_sprite_node.position.y)
	var ghost_transform: Transform2D = Transform2D(dynamic_entity.rotation, ghost_pos)

	var ghost_instance: SpriteGhost = SpriteGhost.create(ghost_scene, ghost_transform, dynamic_entity.scale, sprite_texture, ghost_fade_time)
	add_child(ghost_instance)
	ghosts_spawned += 1

func _play_dash_sound() -> void:
	AudioManager.play_sound("PlayerDash", AudioManager.SoundType.SFX_GLOBAL)

func _stop_dash_sound() -> void:
	AudioManager.fade_out_sound_by_name("PlayerDash", 0.1, 1, true)

## If there is a non-zero movement vector, go to the run state, otherwise go to the idle state.
func _travel_to_next_state() -> void:
	if movement_vector != Vector2.ZERO:
		transitioned.emit(self, "Run")
	else:
		transitioned.emit(self, "Idle")

func _on_dash_timer_timeout() -> void:
	_travel_to_next_state()
