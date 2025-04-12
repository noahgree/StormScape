extends State
class_name StunnedState
## Handles when the entity is stunned. This is a required state for all dynamic entities.

@export var indicator_scene: PackedScene = load("res://Entities/Stats/EffectSystemResources/StatusEffects/BadEffects/Stun/StunIndicator.tscn") ## The instance that will be spawned above the character to indicate stun.

var stun_indicator: AnimatedSprite2D ## The animated sprite showing the stun indicator over the entity.


func enter() -> void:
	entity.facing_component.travel_anim_tree("idle")
	_animate()
	_create_stun_indicator()

	if entity.hands and entity.hands.equipped_item != null:
		if entity.hands.equipped_item is ProjectileWeapon:
			entity.hands.equipped_item.hold_time = 0

func exit() -> void:
	if stun_indicator:
		stun_indicator.queue_free()
	controller.stunned_timer.stop()

func state_physics_process(delta: float) -> void:
	_do_character_stun(delta)
	if stun_indicator:
		_update_stun_indicator_pos()

func _do_character_stun(delta: float) -> void:
	var knockback: Vector2 = controller.knockback_vector
	if knockback.length() > 0:
		entity.velocity = knockback

	if entity.velocity.length() > (entity.stats.get_stat("friction") * delta): # Still slowing
		entity.velocity -= entity.velocity.normalized() * (entity.stats.get_stat("friction") * delta)
	else:
		entity.velocity = Vector2.ZERO
	entity.move_and_slide()

func _animate() -> void:
	entity.facing_component.update_blend_position("idle")

## Creates the stun indicator scene above the entity and adds it as a child.
func _create_stun_indicator() -> void:
	stun_indicator = indicator_scene.instantiate()
	add_child(stun_indicator)
	stun_indicator.hide()

## Update where the stun indicator should be based on the entity size and position.
func _update_stun_indicator_pos() -> void:
	var sprite_texture: Texture2D = SpriteHelpers.SpriteDetails.get_frame_texture(entity.sprite)
	var sprite_offset: Vector2 = entity.sprite.position - Vector2(0, sprite_texture.get_size().y / 2)
	stun_indicator.global_position = entity.position + sprite_offset
	stun_indicator.show()
