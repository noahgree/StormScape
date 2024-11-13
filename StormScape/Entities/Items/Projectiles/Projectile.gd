extends HitboxComponent
class_name Projectile
## The viusal representation of the projectile. Defines all needed methods for how to travel and seek, with the flags for what
## to do being set by whatever spawns the projectile.

@export var whiz_sound: String = ""
@export_range(0, 100, 0.1, "suffix:%") var glow_strength: float = 0
@export var glow_color: Color = Color(1, 1, 1)
@export var impact_vfx: PackedScene = null
@export var impact_sound: String = ""

@onready var previous_position: Vector2 = global_position
@onready var sprite: Sprite2D = $Sprite2D

var stats: ProjectileResource

static func spawn(weapon_stats: ProjWeaponResource, pos: Vector2, rot: float) -> Projectile:
	var proj: Projectile = weapon_stats.projectile.instantiate()
	proj.global_position = pos
	proj.rotation = rot
	proj.stats = weapon_stats.projectile_data
	proj.effect_source = weapon_stats.effect_source
	proj.collision_mask = weapon_stats.effect_source.scanned_phys_layers
	return proj

func _ready() -> void:
	super._ready()
	z_index = -1

	var start_offset: int = int(floor(sprite.region_rect.size.x / 2.0))
	var offset_vector: Vector2 = Vector2(start_offset, 0).rotated(global_rotation)
	global_position += offset_vector

func _physics_process(delta: float) -> void:
	position += transform.x * stats.speed * delta
	movement_direction = (global_position - previous_position).normalized()

func _process_hit(_area: Area2D) -> void:
	queue_free()
