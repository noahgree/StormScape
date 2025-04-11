@tool
@icon("res://Utilities/Debug/EditorIcons/projectile_weapon.png")
extends ProjectileWeapon
class_name UniqueProjWeapon
## A subclass of projectile weapon that adds extra logic for handling unique projectiles. These cannot hitscan.

var returned: bool = true: ## Whether the unique projectile has come back yet. Gets reset when dropped, but any cooldowns are saved.
	set(new_value):
		if Engine.is_editor_hint():
			return

		if returned == false and new_value == true:
			var cooldown: float = stats.fire_cooldown if stats.firing_mode != ProjWeaponResource.FiringType.CHARGE else stats.charge_fire_cooldown
			_add_cooldown(cooldown)

		returned = new_value

		if new_value == true:
			sprite.show()
		else:
			sprite.hide()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	tree_exiting.connect(_on_tree_exiting)
	if not returned:
		sprite.hide()
	super._ready()

func _fire() -> void:
	if returned:
		super._fire()

func _charge_fire() -> void:
	if returned:
		super._charge_fire()

func _spawn_projectile(proj: Projectile) -> void:
	returned = false
	proj.source_weapon_instance = self
	super._spawn_projectile(proj)

func _on_tree_exiting() -> void:
	if not returned:
		var cooldown: float = stats.fire_cooldown if stats.firing_mode != ProjWeaponResource.FiringType.CHARGE else stats.charge_fire_cooldown
		_add_cooldown(cooldown)

## Checks for a cooldown and adds it to the manager. Then updates the visuals if needed.
func _add_cooldown(duration: float, title: String = "default") -> void:
	if duration <= 0:
		return
	source_entity.inv.auto_decrementer.add_cooldown(stats.get_cooldown_id(), duration, Callable(), title)

## Only exists to override the parent function so that we can do our own, different logic here.
## Does nothing on purpose in this script.
func _handle_adding_cooldown(_duration: float, _title: String = "default") -> void:
	return
