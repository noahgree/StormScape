extends Node
## A global singleton containing all data needed globally.

@onready var world_root: WorldRoot = get_parent().get_node("Game/WorldRoot") ## A reference to the root of the game world.
@onready var storm: Storm = get_parent().get_node("Game/WorldRoot/Storm") ## A reference to the main storm node.

var player_node: Player = null ## The reference to the player's node.
var player_camera: PlayerCamera = null ## The reference to the player's main camera.
var focused_ui_is_open: bool = false ## When true, the main UI that pauses the game is open.


func _ready() -> void:
	player_node = await SignalBus.player_ready
	player_camera = get_parent().get_node("Game/WorldRoot/PlayerCamera")

# EffectReceiver & StatModManager
enum Teams {
	PLAYER = 1 << 0, ## The player team (against the enemies).
	ENEMY = 1 << 1, ## The enemy team (against the player).
	PASSIVE = 1 << 2 ## Does not heal or damage anything. Just exists.
}
enum DmgAffectedStats { HEALTH_ONLY, SHIELD_ONLY, SHIELD_THEN_HEALTH, SIMULTANEOUS }
enum HealAffectedStats { HEALTH_ONLY, SHIELD_ONLY, HEALTH_THEN_SHIELD, SIMULTANEOUS }
enum BadEffectAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }
enum GoodEffectAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }
enum EffectSourceSourceType {
	FROM_DEFAULT, ## For any effect source that does not come from any of the below types.
	FROM_PROJECTILE, ## For damage coming from any normal projectile like a bullet from a sniper or pistol.
	FROM_EXPLOSION, ## For damage coming from AOEs that explode.
	FROM_GROUND_AOE, ## For damage coming from AOEs that exist on the ground like a poison puddle or aftermath of a molotov.
	FROM_MAGIC, ## For magic weapons.
	FROM_TOOL, ## For melee weapons like pickaxes and axes that exist primary to interact with the world resources.
	FROM_PHYSICAL_CONTACT, ## For physcial interactions like a punch or running into something with a hitbox attached to the body.
	FROM_COMBAT_MELEE ## For melee weapons that are primarily damaging weapons like a sword (not tools like the pickaxe).
}

# Items
enum ItemType {
	CONSUMABLE, WEAPON, AMMO, CLOTHING, WORLD_RESOURCE, SPECIAL, WEAPON_MOD
}
const all_proj_weapons: Array[ProjWeaponResource.ProjWeaponType] = [ProjWeaponResource.ProjWeaponType.PISTOL, ProjWeaponResource.ProjWeaponType.SHOTGUN, ProjWeaponResource.ProjWeaponType.SMG, ProjWeaponResource.ProjWeaponType.SNIPER, ProjWeaponResource.ProjWeaponType.RIFLE, ProjWeaponResource.ProjWeaponType.EXPLOSIVE, ProjWeaponResource.ProjWeaponType.PRIMITIVE, ProjWeaponResource.ProjWeaponType.MAGICAL, ProjWeaponResource.ProjWeaponType.THROWABLE, ProjWeaponResource.ProjWeaponType.SPECIAL]
const all_melee_wpns: Array[MeleeWeaponResource.MeleeWeaponType] = [MeleeWeaponResource.MeleeWeaponType.TOOL, MeleeWeaponResource.MeleeWeaponType.PHYSICAL, MeleeWeaponResource.MeleeWeaponType.COMBAT]

enum ItemRarity {
	COMMON,  ## [b][color=darkgray]0[/color][/b]
	UNCOMMON, ## [b][color=green]1[/color][/b]
	RARE, ## [b][color=dodgerblue]2[/color][/b]
	EPIC, ## [b][color=purple]3[/color][/b]
	LEGENDARY, ## [b][color=gold]4[/color][/b]
	SINGULAR ## [b][color=deeppink]5[/color][/b]
}
const rarity_colors: Dictionary[String, Dictionary] = {
	"ground_glow" : {
		ItemRarity.COMMON : Color(0.617, 0.625, 0.633),
		ItemRarity.UNCOMMON : Color(0, 0.743, 0.433),
		ItemRarity.RARE : Color(0, 0.611, 0.98),
		ItemRarity.EPIC : Color(0.613, 0.475, 1),
		ItemRarity.LEGENDARY : Color(0.926, 0.605, 0),
		ItemRarity.SINGULAR : Color(0.97, 0.13, 0.381)
	},
	"outline_color": {
		ItemRarity.COMMON : Color(0.617, 0.625, 0.633),
		ItemRarity.UNCOMMON : Color(0, 0.743, 0.433),
		ItemRarity.RARE : Color(0, 0.611, 0.98),
		ItemRarity.EPIC : Color(0.53, 0.5, 1.45),
		ItemRarity.LEGENDARY : Color(1.586, 0.655, 0),
		ItemRarity.SINGULAR :  Color(1.45, 0.3, 0.5)
	},
	"tint_color" : {
		ItemRarity.COMMON : Color(0.617, 0.625, 0.633, 0.05),
		ItemRarity.UNCOMMON : Color(0, 0.743, 0.433, 0.05),
		ItemRarity.RARE : Color(0, 0.611, 0.98, 0.05),
		ItemRarity.EPIC : Color(0.613, 0.475, 1, 0.07),
		ItemRarity.LEGENDARY : Color(0.926, 0.605, 0, 0.07),
		ItemRarity.SINGULAR : Color(0.946, 0.3, 0.41, 0.07)
	},
	"glint_color" : {
		ItemRarity.COMMON : Color(0.617, 0.625, 0.633),
		ItemRarity.UNCOMMON : Color(0, 0.743, 0.433),
		ItemRarity.RARE : Color(0, 0.611, 0.98),
		ItemRarity.EPIC : Color(0.613, 0.475, 1),
		ItemRarity.LEGENDARY : Color(0.926, 0.605, 0),
		ItemRarity.SINGULAR : Color(0.946, 0, 0.381)
	},
	"slot_glow" : {
		ItemRarity.COMMON : Color(1.0, 1.0, 1.0),
		ItemRarity.UNCOMMON : Color(0, 0.9659, 0.5629),
		ItemRarity.RARE : Color(0, 0.95, 1.55),
		ItemRarity.EPIC : Color(0.9195, 0.7125, 1.5),
		ItemRarity.LEGENDARY : Color(1.389, 0.9075, 0),
		ItemRarity.SINGULAR : Color(1.31, 0.997, 1.018)
	},
	"slot_fill" : {
		ItemRarity.COMMON : Color(0.517, 0.525, 0.533, 0.75),
		ItemRarity.UNCOMMON : Color(0.226, 0.627, 0.429, 0.75),
		ItemRarity.RARE : Color(0, 0.681, 1.0, 0.75),
		ItemRarity.EPIC : Color(0.545, 0.312, 1, 0.75),
		ItemRarity.LEGENDARY : Color(0.948, 0.642, 0, 0.75),
		ItemRarity.SINGULAR : Color(0.805, 0.266, 0.443, 0.75)
	}
}
