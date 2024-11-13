extends Weapon
class_name MeleeWeapon

@onready var anim_player: AnimationPlayer = $AnimationPlayer ## The animation controller for this melee weapon.
@onready var hitbox_component: HitboxComponent = $AnimatedSprite2D/HitboxComponent ## The hitbox responsible for applying the melee hit.


func _set_stats(new_stats: ItemResource) -> void:
	stats = new_stats
	if hitbox_component:
		hitbox_component.effect_source = stats.effect_source
		hitbox_component.collision_mask = hitbox_component.effect_source.scanned_phys_layers

func enter() -> void:
	pass

func exit() -> void:
	source_entity.move_fsm.should_rotate = true

## Overrides the parent method to specify what to do on use while equipped.
func activate() -> void:
	_swing()

func _swing() -> void:
	stats.effect_source.source_entity = source_entity

	source_entity.move_fsm.should_rotate = false

	var anim: Animation = anim_player.get_animation("use")
	var main_sprite_track: int = anim.find_track("AnimatedSprite2D:rotation", Animation.TYPE_VALUE)
	anim.track_set_key_value(main_sprite_track, 1, deg_to_rad(stats.swing_angle))

	anim_player.speed_scale = 1.0 / stats.use_speed
	anim_player.play("use")

func _on_animation_ended() -> void:
	source_entity.move_fsm.should_rotate = true
