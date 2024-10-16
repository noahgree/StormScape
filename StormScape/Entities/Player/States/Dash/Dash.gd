extends State
## Handles when the character is dashing.


@export var dash_speed: float = 1200 ## How fast the dash moves the character.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var dash_duration: float = 0.1 ## The dash duration.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var dash_cooldown: float = 1.0 ## The dash cooldown.
@export var ghost_scene: PackedScene ## The scene that defines the ghosts' behavior.
@export var ghost_count: int = 8 ## How many ghosts to make during the dash.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var ghost_fade_time: float = 0.1 ## How long ghosts take to fade.

@onready var dash_timer: Timer = %DashTimer ## Timer to enforce how long the dash lasts for.

var movement_vector: Vector2 = Vector2.ZERO ## The current direction of movement.
var ghosts_spawned: int = 0 ## The number of ghosts spawned so far in this dash.
var time_since_ghost: float = 0.0 ## The number of seconds since the last ghost spawn.
var can_spawn_ghosts: bool = false ## Whether we have the proper node to enable ghost spawns during dash.


func enter() -> void:
	state_machine.anim_tree["parameters/playback"].travel("run")
	
	ghosts_spawned = 0
	dash_timer.start(dash_duration)
	state_machine.dash_cooldown_timer.start(dash_duration + dash_cooldown)
	movement_vector = _calculate_move_vector()
	state_machine.anim_pos = movement_vector
	
	if parent.has_node("AnimatedSprite2D"):
		_create_ghost()
		can_spawn_ghosts = true

func exit() -> void:
	dash_timer.stop()
	parent.velocity = Vector2.ZERO

## Ticks the time since last ghost spawn.
func state_process(delta: float) -> void:
	if can_spawn_ghosts:
		time_since_ghost += delta
		_update_ghost_spawns(delta)

func state_physics_process(delta: float) -> void:
	_animate()
	_do_character_dash()

## Overrides the parent velocity to be a simple dash in the direction currently faced.
func _do_character_dash() -> void:
	parent.velocity = movement_vector * dash_speed
	parent.move_and_slide()

func _calculate_move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()

func _animate() -> void:
	state_machine.anim_tree.set("parameters/run/blendspace2d/blend_position", state_machine.anim_pos)

## Checks if we have spent enough time since the last ghost and if we haven't spawned enough yet, then spawns one.
func _update_ghost_spawns(delta: float) -> void:
	if (ghosts_spawned < ghost_count) and (time_since_ghost >= (dash_duration / ghost_count)):
		_create_ghost()
		time_since_ghost = 0.0

## Grabs the current animation frame texture and creates a ghost from it, adding it at the proper offset as a child.
func _create_ghost() -> void:
	var animated_sprite_node = parent.get_node("AnimatedSprite2D")
	var current_anim: String = animated_sprite_node.animation
	var current_frame: int = animated_sprite_node.frame
	var sprite_texture: Texture2D = animated_sprite_node.sprite_frames.get_frame_texture(current_anim, current_frame)
	
	var ghost_instance = ghost_scene.instantiate()
	var ghost_pos: Vector2 = Vector2(parent.position.x + animated_sprite_node.position.x, parent.position.y + animated_sprite_node.position.y)
	ghost_instance.init(ghost_pos, parent.scale, sprite_texture, ghost_fade_time)
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
