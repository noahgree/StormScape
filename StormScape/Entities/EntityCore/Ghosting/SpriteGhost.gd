extends Sprite2D
class_name SpriteGhost
## A simple sprite2D node to handle fading and queue freeing a ghost instance during something like a dash state.

static var ghost_scene: PackedScene = preload("res://Entities/EntityCore/Ghosting/SpriteGhost.tscn")

var fade_out_time: float ## How long the sprite takes to fade out after being instanced.
var is_whitened: bool = false
const NON_WHITENED_ALPHA: float = 0.6


## Takes in relevant data to instance the node in the world as a ghost, including a custom fade out time.
static func create(trans: Transform2D, size: Vector2,
					sprite_frame: Texture2D, fade_time: float) -> SpriteGhost:
	var ghost_instance: SpriteGhost = ghost_scene.instantiate()
	ghost_instance.transform = trans
	ghost_instance.scale = size
	ghost_instance.z_index = -1
	if sprite_frame:
		ghost_instance.texture = sprite_frame
	ghost_instance.fade_out_time = fade_time
	return ghost_instance

func make_white() -> void:
	set_instance_shader_parameter("whitener_enabled", true)
	is_whitened = true

func _ready() -> void:
	_do_ghosting()

## Creates the tween for handling the fade out, waits for the fade to finish, then queue frees the node.
func _do_ghosting() -> void:
	var fade_out_tween: Tween = create_tween()
	set_instance_shader_parameter("alpha_multiplier", 0.15)
	fade_out_tween.tween_property(self, "instance_shader_parameters/alpha_multiplier", 0.0, fade_out_time)
	if not is_whitened:
		set_instance_shader_parameter("alpha_multiplier", NON_WHITENED_ALPHA)

	await fade_out_tween.finished
	queue_free()
