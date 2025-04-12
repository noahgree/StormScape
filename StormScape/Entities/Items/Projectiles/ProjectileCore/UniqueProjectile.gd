extends Projectile
class_name UniqueProjectile
## These are projectiles that persist in some way. They might recharge, fly back to the sender, etc.

var source_weapon: UniqueProjWeapon = null ## The unique proj weapon that spawned this projectile.


func _ready() -> void:
	if is_instance_valid(source_weapon):
		source_weapon.tree_exiting.connect(queue_free)
	super._ready()

## Let the source weapon know we have freed if it still exists.
func _exit_tree() -> void:
	if is_instance_valid(source_weapon) and source_weapon != null:
		source_weapon.returned = true
