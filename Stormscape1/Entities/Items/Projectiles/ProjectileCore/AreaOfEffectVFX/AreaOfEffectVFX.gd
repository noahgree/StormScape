extends Node2D
class_name AreaOfEffectVFX
## The VFX that spawns upon an AOE projectile triggering.

@export var particles_nodes: Array[CPUParticles2D] = [] ## All particle nodes that have a radius and need to be tweened out at the end.
@export var border_color: Color = Color(0.827, 0.272, 0.0, 0.65) ## The border of the circle's color.
@export var fill_color: Color = Color(0.827, 0.0, 0.177, 0.5) ## The inside of the circle's color.
@export var floor_light_color: Color = Color(1.0, 0.635, 0.271) ## The color of the floor light.

@onready var floor_light: PointLight2D = $FloorLight ## The floor light that shines up.

var radius: float ## The radius of the particles and other indicators.
var duration: float ## The duration of the visuals before fading.
var lifetime_timer: Timer = TimerHelpers.create_one_shot_timer(self, 1.0, _on_lifetime_ending, "VFXLifeTimer")
var pulse_tween: Tween ## The tween tracking the pulsing of the circle color.
const RADIUS_TO_BASE_OFF_OF: float = 20.0 ## The radius to base the floor light resizing calculations off of.
const MAX_PARTICLE_COUNT: int = 80 ## The max amount any single particle emitter can emit.


## Creates and sets up an AOE VFX scene.
static func create(scene: PackedScene, tree_parent: Node2D, life_and_loc_parent: Node2D,
					vfx_radius: float, vfx_duration: float) -> void:
	var vfx_scene: AreaOfEffectVFX = scene.instantiate()
	vfx_scene.radius = vfx_radius
	vfx_scene.duration = vfx_duration

	tree_parent.add_child(vfx_scene)
	vfx_scene.global_position = life_and_loc_parent.global_position

func _ready() -> void:
	lifetime_timer.start(duration)

	for node: CPUParticles2D in particles_nodes:
		node.amount = min(int(node.amount * (radius / node.emission_sphere_radius)), MAX_PARTICLE_COUNT)
		node.emission_sphere_radius = radius

	floor_light.texture_scale *= (radius / RADIUS_TO_BASE_OFF_OF)
	floor_light.color = floor_light_color

	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(self, "fill_color:a", fill_color.a * 0.35, 0.75).set_delay(0.05)
	pulse_tween.tween_property(self, "fill_color:a", fill_color.a, 0.75).set_delay(0.05)

func _process(_delta: float) -> void:
	queue_redraw()

## Draw the circle and its border to indicate the area of effect.
func _draw() -> void:
	for x: int in range(-radius, radius, 1):
		for y: int in range(-radius, radius, 1):
			var dist_sq: int = x * x + y * y
			if dist_sq <= radius * radius:
				# Checks if the current pixel is on the border
				if dist_sq >= (radius - 1) * (radius - 1) and dist_sq < radius * radius:
					draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), border_color)
				else:
					draw_rect(Rect2(Vector2(x, y), Vector2(1, 1)), fill_color)

## When the lifetime timer ends, start the tweens to fade things out and then queue free.
func _on_lifetime_ending() -> void:
	for node: CPUParticles2D in particles_nodes:
		node.emitting = false

	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(floor_light, "energy", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
