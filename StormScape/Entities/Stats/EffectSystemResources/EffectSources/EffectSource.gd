extends Resource
class_name EffectSource
## A base class for all instances in the game that can apply effects like damage and knockback.
##
## Should be the superclass for all effect sources.
## This contains all the data needed by an effect receiver, and nothing more. Textures, animations, hitboxes, etc.
## should be handled by the producer of this effect source. This is purely data.

@export_group("General")
@export var source_type: Globals.EffectSourceSourceType ## A tag used to determine the source of the effect source. See Globals class for details on the tags.
@export var source_tags: Array[String] = [] ## Additional information to pass to whatever receieves this effect source to make sure it should apply.
@export_flags_2d_physics var scanned_phys_layers: int = 0b1101111 ## The collision mask that this source scans in order to apply affects to.
@export_subgroup("Team Logic")
@export var can_hit_self: bool = true ## Whether or not this effect source can be applied to what created it.
@export_flags("Enemies", "Allies") var bad_effect_affected_teams: int = Globals.BadEffectAffectedTeams.ENEMIES ## Which entity teams in relation to who produced this source are affected by this damage.
@export_flags("Enemies", "Allies") var good_effect_affected_teams: int = Globals.GoodEffectAffectedTeams.ALLIES ## Which entity teams in relation to who produced this source are affected by this healing.

@export_group("Base Damage")
@export var base_damage: int: ## The base numerical amount of damage associated with this effect source.
	set(new_value):
		base_damage = max(0, new_value)
@export var object_damage_mult: float = 1.0 ## A multiplier for doing more damage to Static & Rigid entities marked as objects.
@export var dmg_affected_stats: Globals.DmgAffectedStats = Globals.DmgAffectedStats.SHIELD_THEN_HEALTH ## Which entity stats are affected by this damage source.
@export_range(0, 100, 1, "suffix:%") var crit_chance: int = 0 ## The chance the application of damage will be a critial hit.
@export var crit_multiplier: float = 1.5 ## How much stronger critical hits are than normal hits.
@export_range(0, 100, 1, "suffix:%") var armor_penetration: int = 0 ## The percent of armor ignored.

@export_group("Base Healing")
@export var base_healing: int: ## The base numerical amount of health associated with this effect source.
	set(new_value):
		base_healing = max(0, new_value)
@export var heal_affected_stats: Globals.HealAffectedStats = Globals.HealAffectedStats.HEALTH_THEN_SHIELD ## Which entity stats are affected by this healing source.

@export_group("Impact FX")
@export var impact_cam_fx: CamFXResource ## The resource defining how the camera should react to firing.
@export var impact_vfx: PackedScene = null ## The vfx to spawn when impacting something.
@export var impact_sound: String = "" ## The sound to play when impacting something.
@export var hit_flash_color: Color = Color(1, 1, 1, 0.6) ## The color to flash the hit entity to on being hit.

@export_group("Status Effects")
@export var status_effects: Array[StatusEffect] ## The array of status effects that can be applied to the receiving entity.


# Unique Properties #
@export_storage var contact_position: Vector2 ## The position of what the effect source is attached to when it makes contact with a receiver.
@export_storage var movement_direction: Vector2 ## The direction vector of this effect source at contact used for knockback.
@export_storage var multishot_id: int = -1 ## The id used to relate multishot projectiles with each other. Unique to each game load. -1 means it did not come from a multishot.


## Looks to see if there is a status effect with the matching name in this effect source's array of status effects. Return its index
## if found, else return -1. Does not handle duplicates.
func check_for_effect_and_get_index(name: String) -> int:
	for i: int in range(status_effects.size()):
		if status_effects[i].id == name:
			return i
	return -1
