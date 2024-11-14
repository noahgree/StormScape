extends EquippableItem
class_name Weapon

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D ## The required animated sprite node for all weapons.

var pullout_delay_timer: Timer = Timer.new()


func _ready() -> void:
	super._ready()

	add_child(pullout_delay_timer)
	pullout_delay_timer.one_shot = true
	if stats.pullout_delay > 0:
		pullout_delay_timer.start(stats.pullout_delay)
