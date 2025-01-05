extends Sprite2D
class_name WeaponVFX

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var lifetime: float = 0.02

var lifetime_counter: float


func _ready() -> void:
	lifetime_counter = lifetime

func _process(delta: float) -> void:
	lifetime_counter -= delta
	if lifetime_counter <= 0:
		_lifetime_ended()

func _lifetime_ended() -> void:
	queue_free()
