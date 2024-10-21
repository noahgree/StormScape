extends DynamicState
## Handles when the character is dashing.

@export var _dash_speed: float = 1200 ## How fast the dash moves the character.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _dash_duration: float = 0.1 ## The dash duration.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var _dash_cooldown: float = 1.0 ## The dash cooldown.
@export var ghost_scene: PackedScene ## The scene that defines the ghosts' behavior.
@export var ghost_count: int = 8 ## How many ghosts to make during the dash.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.1 ## How long ghosts take to fade.

@onready var dash_timer: Timer = %DashTimer ## Timer to enforce how long the dash lasts for.

var movement_vector: Vector2 = Vector2.ZERO ## The current direction of movement.
var ghosts_spawned: int = 0 ## The number of ghosts spawned so far in this dash.
var time_since_ghost: float = 0.0 ## The number of seconds since the last ghost spawn.
var can_spawn_ghosts: bool = false ## Whether we have the proper node to enable ghost spawns during dash.
var parent_sprite_node: Node2D


func _ready() -> void:
	var moddable_stats: Dictionary = {
		"dash_speed" : _dash_speed, "dash_duration" : _dash_duration, 
		"dash_cooldown" : _dash_cooldown
	}
	fsm.add_moddable_stats(moddable_stats)

func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("run")
	fsm.knockback_vector = Vector2.ZERO
	fsm.can_receive_effects = false
	
	ghosts_spawned = 0
	dash_timer.start(fsm.get_stat("dash_duration"))
	fsm.dash_cooldown_timer.start(fsm.get_stat("dash_duration") + fsm.get_stat("dash_cooldown"))
	movement_vector = _calculate_move_vector()
	fsm.anim_vector = movement_vector
	
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
	dynamic_entity.velocity = movement_vector * fsm.get_stat("dash_speed")
	dynamic_entity.move_and_slide()

func _calculate_move_vector() -> Vector2:
	return _get_input_vector()

func _animate() -> void:
	fsm.anim_tree.set("parameters/run/blendspace2d/blend_position", fsm.anim_vector)

## Checks if we have spent enough time since the last ghost and if we haven't spawned enough yet, then spawns one.
func _update_ghost_spawns() -> void:
	if (ghosts_spawned < ghost_count) and (time_since_ghost >= (fsm.get_stat("dash_duration") / ghost_count)):
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
	
	var ghost_instance = ghost_scene.instantiate()
	var ghost_pos: Vector2 = Vector2(dynamic_entity.position.x + parent_sprite_node.position.x, dynamic_entity.position.y + parent_sprite_node.position.y)
	
	ghost_instance.init(ghost_pos, dynamic_entity.scale, sprite_texture, ghost_fade_time)
	add_child(ghost_instance)
	ghosts_spawned += 1

## If there is a non-zero movement vector, go to the run state, otherwise go to the idle state.
func _travel_to_next_state() -> void:
	if movement_vector != Vector2.ZERO:
		Transitioned.emit(self, "Run")
	else:
		Transitioned.emit(self, "Idle")

func _on_dash_timer_timeout() -> void:
	_travel_to_next_state()
