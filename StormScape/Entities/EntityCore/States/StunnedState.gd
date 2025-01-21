extends State
class_name StunnedState
## Handles when the entity is stunned. This is a required state for all dynamic entities.

@export var indicator_scene: PackedScene ## The instance that will be spawned above the character to indicate stun.

@onready var stunned_timer: Timer = $StunnedTimer ## The timer that tracks how much longer the stun has remaining.

var stun_indicator: AnimatedSprite2D ## The animated sprite showing the stun indicator over the entity.


func enter() -> void:
	fsm.anim_tree["parameters/playback"].travel("idle")
	stunned_timer.start()
	_animate()
	_create_stun_indicator()

	if entity.hands != null:
		entity.hands.been_holding_time = 0

func exit() -> void:
	if stun_indicator: stun_indicator.queue_free()

func state_physics_process(delta: float) -> void:
	_do_character_stun(delta)
	if stun_indicator: _update_stun_indicator_pos()

func _do_character_stun(delta: float) -> void:
	var knockback: Vector2 = fsm.knockback_vector
	if knockback.length() > 0:
		entity.velocity = knockback

	if entity.velocity.length() > (entity.stats.get_stat("friction") * delta): # Still slowing
		entity.velocity -= entity.velocity.normalized() * (entity.stats.get_stat("friction") * delta)
	else:
		entity.velocity = Vector2.ZERO
	entity.move_and_slide()

func _animate() -> void:
	fsm.anim_tree.set("parameters/idle/blendspace2d/blend_position", fsm.anim_vector)

## Creates the stun indicator scene above the entity and adds it as a child.
func _create_stun_indicator() -> void:
	stun_indicator = indicator_scene.instantiate()
	add_child(stun_indicator)

## Update where the stun indicator should be based on the entity size and position.
func _update_stun_indicator_pos() -> void:
	var sprite_texture: Texture2D = SpriteHelpers.SpriteDetails.get_frame_texture(entity.sprite)
	var sprite_offset: Vector2 = entity.sprite.position - Vector2(0, sprite_texture.get_size().y / 2)
	stun_indicator.global_position = entity.position + sprite_offset

## When the stun time has ended, transition out of this state and back to Idle.
func _on_stunned_timer_timeout() -> void:
	transitioned.emit(self, "Idle")
