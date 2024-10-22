extends Resource
class_name EffectSource
## A base class for all instances in the game that can apply effects like damage and knockback. 
##
## Should be the superclass for all effect sources.
## This contains all the data needed by an effect receiver, and nothing more. Textures, animations, hitboxes, etc.
## should be handled by the producer of this effect source. This is purely data.

@export_group("Teams & Layers")
@export var source_team: EnumUtils.Teams = EnumUtils.Teams.ENEMY ## Should eventually be set by what produces this effect. Used for determining which parts are applied.
@export_flags("Enemies", "Allies") var bad_effect_affected_teams: int = EnumUtils.BadEffectAffectedTeams.ENEMIES ## Which entity teams in relation to who produced this source are affected by this damage.
@export_flags("Enemies", "Allies") var good_effect_affected_teams: int = EnumUtils.GoodEffectAffectedTeams.ALLIES ## Which entity teams in relation to who produced this source are affected by this healing.
@export_subgroup("Scanned Physics Layers")
@export_flags("Player", "Player Attacks", "Enemies", "Enemy Attacks", "Objects", "Terrain", "World Areas", "Layer 8") var scanned_phys_layers: int = 0b00011111 ## The collision mask that this source scans in order to apply affects to.

@export_group("Base Damage")
@export var base_damage: int ## The base numerical amount of damage associated with this effect source.
@export var dmg_affected_stats: EnumUtils.DmgAffectedStats = EnumUtils.DmgAffectedStats.SHIELD_THEN_HEALTH ## Which entity stats are affected by this damage source.
@export_range(0.0, 1.0, 0.01, "suffix:%") var crit_chance: float = 0.0 ## The chance the application of damage will be a critial hit.
@export var crit_multiplier: float = 1.5 ## How much stronger critical hits are than normal hits.
@export_range(0.0, 1.0, 0.01, "suffix:%") var armor_penetration: float = 0.0 ## The percent of armor ignored.

@export_group("Healing Method")
@export var base_healing: int ## The base numerical amount of health associated with this effect source.
@export var heal_affected_stats: EnumUtils.HealAffectedStats = EnumUtils.HealAffectedStats.HEALTH_THEN_SHIELD ## Which entity stats are affected by this healing source.

@export_group("Status Effects")
@export var status_effects: Array[StatusEffect]

var source_entity
var contact_position: Vector2
var movement_direction: Vector2
var is_source_moving_type: bool
