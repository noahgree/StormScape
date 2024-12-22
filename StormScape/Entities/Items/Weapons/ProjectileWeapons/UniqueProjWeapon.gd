extends ProjectileWeapon
class_name UniqueProjWeapon
## A subclass of projectile weapon that adds extra logic for handling unique projectiles. These cannot hitscan.

var returned: bool = true: ## Whether the unique projectile has come back yet. Gets reset when dropped, but any cooldowns are saved.
	set(new_value):
		if returned == false and new_value == true:
			_add_cooldown()

		returned = new_value

		if new_value == true:
			sprite.show()
		else:
			sprite.hide()


func _ready() -> void:
	tree_exiting.connect(_on_tree_exiting)
	if not returned:
		sprite.hide()
	super._ready()

func _fire() -> void:
	if returned:
		super._fire()

func _charge_fire(hold_time: float) -> void:
	if returned:
		super._charge_fire(hold_time)

func _spawn_projectile(proj: Projectile, was_charge_fire: bool = false) -> void:
	returned = false
	proj.source_weapon_instance = self
	super._spawn_projectile(proj, was_charge_fire)

func _on_tree_exiting() -> void:
	if not returned:
		_add_cooldown()

## Checks for a cooldown and adds it to the manager. Then updates the visuals if needed.
func _add_cooldown() -> void:
	var cooldown: float = stats.fire_cooldown if stats.firing_mode != "Charge" else stats.charge_fire_cooldown
	if cooldown > 0:
		source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), cooldown)

## Only exists to override the parent function so that we can do our own, different logic here. Does nothing on purpose in this script.
func _update_cooldown_with_potential_visuals(_duration: float) -> void:
	return
