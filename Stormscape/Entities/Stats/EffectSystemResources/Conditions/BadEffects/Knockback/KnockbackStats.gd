@icon("res://Utilities/Debug/EditorIcons/knockback_effect.png")
extends Condition
class_name KnockbackStats

@export var knockback_force: int = 0 ## The magnitude of knockback applied to the entity receiving this damage.
@export var custom_knockback_direction: Vector2  = Vector2.ZERO ## Overrides how knockback wouold normally be applied to send the entity in this direction only. Only change this if you want to override.
