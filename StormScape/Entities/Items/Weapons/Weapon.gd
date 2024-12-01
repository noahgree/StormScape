extends EquippableItem
class_name Weapon
## The base class for all equippable weapons in the game.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D ## The required animated sprite node for all weapons.
@onready var weapon_mod_manager: WeaponModManager = $WeaponModManager ## The node managing weapon mods.

var pullout_delay_timer: Timer = Timer.new() ## The timer managing the delay after a weapon is equipped before it can be used.
var cache_is_setup_after_load: bool = false


func _set_stats(new_stats: ItemResource) -> void:
	super._set_stats(new_stats)


func _ready() -> void:
	assert(has_node("WeaponModManager"), name + " does not have a weapon mod manager node attached.")
	super._ready()

	add_child(pullout_delay_timer)
	pullout_delay_timer.one_shot = true
	if stats.pullout_delay > 0:
		pullout_delay_timer.start(stats.pullout_delay)
