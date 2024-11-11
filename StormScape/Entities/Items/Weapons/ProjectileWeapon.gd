extends Weapon
class_name ProjectileWeapon

@export var stats: ProjWeaponResource = null: set = _set_wpn ## The resource driving the stats and type of weapon.

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var proj_origin: Marker2D = $ProjectileOrigin


func _set_wpn(wpn_stats: ProjWeaponResource) -> void:
	stats = wpn_stats

func _ready() -> void:
	_set_wpn(stats)

func fire(source_entity: PhysicsBody2D) -> void:
	var proj: Projectile = Projectile.spawn(stats.projectile, stats.projectile_data, proj_origin.global_position, global_rotation, source_entity)
	GlobalData.world_root.add_child(proj)
