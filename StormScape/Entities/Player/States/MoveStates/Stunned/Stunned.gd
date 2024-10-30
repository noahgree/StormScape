extends MoveState
## Handles when the entity is stunned. This is a required state for all dynamic entities.

@export var indicator_scene: PackedScene ## The instance that will be spawned above the character to indicate stun.

@onready var stunned_timer: Timer = $StunnedTimer ## The timer that tracks how much longer the stun has remaining.

var stun_indicator: AnimatedSprite2D
var parent_sprite_node: Node2D


func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("idle")
	stunned_timer.start()
	_animate()
	
	if dynamic_entity.has_node("AnimatedSprite2D"):
		parent_sprite_node = dynamic_entity.get_node("AnimatedSprite2D")
	elif dynamic_entity.has_node("Sprite2D"):
		parent_sprite_node = dynamic_entity.get_node("Sprite2D")
	else:
		return
	if parent_sprite_node != null: _create_stun_indicator()

func exit() -> void:
	if stun_indicator: stun_indicator.queue_free()

func state_physics_process(delta: float) -> void:
	_do_character_stun(delta)
	if stun_indicator: _update_stun_indicator_pos()

func _do_character_stun(delta: float) -> void:
	var knockback: Vector2 = fsm.knockback_vector
	if knockback.length() > 0: # let knockback take control if there is any
		dynamic_entity.velocity = knockback
	
	if dynamic_entity.velocity.length() > (dynamic_entity.stats.get_stat("friction") * delta): # still slowing
		dynamic_entity.velocity -= dynamic_entity.velocity.normalized() * (dynamic_entity.stats.get_stat("friction") * delta)
	else:
		dynamic_entity.velocity = Vector2.ZERO
	dynamic_entity.move_and_slide()

func _animate() -> void:
	fsm.anim_tree.set("parameters/idle/blendspace2d/blend_position", fsm.anim_vector)

func _create_stun_indicator() -> void:
	stun_indicator = indicator_scene.instantiate()
	add_child(stun_indicator)

func _update_stun_indicator_pos() -> void:
	var sprite_texture: Texture2D
	if parent_sprite_node is AnimatedSprite2D:
		var animated_sprite_node = dynamic_entity.get_node("AnimatedSprite2D")
		var current_anim: String = animated_sprite_node.animation
		var current_frame: int = animated_sprite_node.frame
		sprite_texture = animated_sprite_node.sprite_frames.get_frame_texture(current_anim, current_frame)
	elif parent_sprite_node is Sprite2D:
		sprite_texture = parent_sprite_node.texture
	stun_indicator.global_position = Vector2(dynamic_entity.position.x + parent_sprite_node.position.x, dynamic_entity.position.y + parent_sprite_node.position.y - (sprite_texture.get_size().y / 2))

## When the stun time has ended, transition out of this state and back to Idle.
func _on_stunned_timer_timeout() -> void:
	Transitioned.emit(self, "Idle")
