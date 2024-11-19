extends Node

@onready var world_root: WorldRoot = get_parent().get_node("Game/WorldRoot")

var player_node: Player = null
var player_camera: PlayerCamera = null
var focused_ui_is_open: bool = false



func _ready() -> void:
	player_node = await SignalBus.player_ready
	player_camera = get_parent().get_node("Game/WorldRoot/PlayerCamera")

# EffectReceiver & StatModManager
enum Teams {
	PLAYER = 1 << 0,
	ENEMY = 1 << 1,
	PASSIVE = 1 << 2 ## Does not heal or damage anything. Just exists.
}

enum DmgAffectedStats { HEALTH_ONLY, SHIELD_ONLY, SHIELD_THEN_HEALTH, SIMULTANEOUS }
enum HealAffectedStats { HEALTH_ONLY, SHIELD_ONLY, HEALTH_THEN_SHIELD, SIMULTANEOUS }

enum BadEffectAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }
enum GoodEffectAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }

# Items
enum ItemType {
	CONSUMABLE, WEAPON, AMMO, CLOTHING, SPECIAL
}
enum ItemRarity {
	COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, SINGULAR
}
enum ProjAmmoType {
	NONE, LIGHT, MEDIUM, HEAVY, SHELL, ROCKET, MAGIC, ION_CHARGE, STAMINA
}
