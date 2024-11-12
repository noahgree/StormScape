extends Weapon
class_name ProjectileWeapon

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var proj_origin: Marker2D = $ProjectileOrigin
@onready var main_hand_pos: Marker2D = get_node_or_null("MainHandPos")


func activate(source_entity: PhysicsBody2D = null) -> void:
	fire(source_entity)

func fire(source_entity: PhysicsBody2D) -> void:
	var proj: Projectile = Projectile.spawn(stats.projectile, stats.projectile_data, proj_origin.global_position, global_rotation, source_entity)
	GlobalData.world_root.add_child(proj)
