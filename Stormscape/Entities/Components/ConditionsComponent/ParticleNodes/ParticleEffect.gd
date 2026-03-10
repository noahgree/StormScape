@tool
extends CPUParticles2D
class_name ParticleEffect
## Wrapper for certain CPUParticle2D nodes that provides extra variables and instantiation handling.
##
## Something else should manage the lifetime of this node. This does not free itself and rather relies on a
## handler to receive a signal when a fade out completes.

signal fade_out_complete(node: ParticleEffect, condition_id: Condition.ID) ## Emitted to tell listeners when a fade out is complete.

@export var condition_id: Condition.ID ## The condition that this particle effect represents. Can be left null if being used for something else.
@export var emission_area: ParticleEmissionComponent.Area ## The area that this particle effect draws over.
@export_custom(PROPERTY_HINT_NONE, "seconds") var fade_in_sec: float = 0 ## How long to fade in the particles for, 0 meaning they just appear instantly.
@export_custom(PROPERTY_HINT_NONE, "seconds") var fade_out_sec: float = 0.35 ## How long to fade out the particles for, 0 meaning they just dissapear instantly.

var tween: Tween ## Controls fading in and out.


## Sets up the particle positioning and extents, then fades it in if necessary.
func start(origin: Vector2, extents: Vector2) -> void:
	emission_sphere_radius = extents.x
	emission_rect_extents = extents
	position = origin

	emitting = true

	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_in_sec)

## Kills any fading tweens and fades out the particles according to the fade out time. Emits a signal when done.
func stop() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_out_sec)
	tween.tween_callback(func() -> void: fade_out_complete.emit(self, condition_id))
