extends StatusEffect
class_name KnockbackEffect

enum KnockbackSourceType { MOVING, STATIC }

@export var knockback_force: int = 0 ## The magnitude of knockback applied to the entity receiving this damage.
@export var knockback_direction: Vector2

var knockback_source_type: KnockbackSourceType
