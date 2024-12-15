extends ProjectileWeapon
class_name UniqueProjWeapon
## A subclass of projectile weapon that adds extra logic for handling unique projectiles. These cannot hitscan.

var returned: bool = true: ## Whether the unique projectile has come back yet. Gets reset when dropped, but any cooldowns are saved.
	set(new_value):
		if returned == false and new_value == true:
			var cooldown: float = stats.fire_cooldown if stats.firing_mode != "Charge" else stats.charge_fire_cooldown
			if cooldown > 0:
				fire_cooldown_timer.start()

		returned = new_value

		if new_value == true:
			sprite.show()
		else:
			sprite.hide()


func _ready() -> void:
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
