extends Projectile
class_name UniqueProjectile
## These are projectiles that persist in some way. They might recharge, fly back to the sender, etc.

var source_weapon_instance: UniqueProjWeapon = null ## The instance of the unique proj weapon that spawned this projectile.


func _ready() -> void:
	tree_exiting.connect(_on_tree_exiting)
	if is_instance_valid(source_weapon_instance):
		source_weapon_instance.tree_exiting.connect(queue_free)
	super._ready()

## Let the source weapon know we have freed if it still exists.
func _on_tree_exiting() -> void:
	if is_instance_valid(source_weapon_instance) and source_weapon_instance != null:
		source_weapon_instance.returned = true
