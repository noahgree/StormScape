extends StatusEffect
class_name KnockbackEffect

enum KnockbackSourceType { MOVING, STATIC }

@export var knockback_force: int = 0 ## The magnitude of knockback applied to the entity receiving this damage.
@export var custom_knockback_direction: Vector2  = Vector2.ZERO ## Overrides how knockback wouold normally be applied to send the entity in this direction only. Only change this if you want to override.

var knockback_source_type: KnockbackSourceType
