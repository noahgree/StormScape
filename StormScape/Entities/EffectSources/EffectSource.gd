extends Area2D
class_name EffectSource
## A base class for all instances in the game that can apply effects like damage and health. 
##
## Should be the superclass for things like projectiles, melee hits, traps, explosions, etc.
## For all intensive purposes, this is acting as a hitbox component.
## By default, there is are exported vars for things like damage, healing, knockback, team, etc... but these 
## can and usually should be overridden by whatever produces this damage source (gun, bomb, etc.).

enum DmgAffectedStats { HEALTH_ONLY, SHIELD_ONLY, SHIELD_THEN_HEALTH, SIMULTANEOUS }
enum HealAffectedStats { HEALTH_ONLY, SHIELD_ONLY, HEALTH_THEN_SHIELD, SIMULTANEOUS }
enum DmgTimeline { INSTANT, OVER_TIME }
enum HealTimeline { INSTANT, OVER_TIME }
enum DmgAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }
enum HealAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }

@export_group("Teams & Layers")
@export var source_team: EnumUtils.Teams = EnumUtils.Teams.ENEMY ## Should eventually be set by what produces this effect. Used for determining which parts are applied.
@export_flags("Enemies", "Allies") var dmg_affected_teams: int = DmgAffectedTeams.ENEMIES ## Which entity teams in relation to who produced this source are affected by this damage.
@export_flags("Enemies", "Allies") var heal_affected_teams: int = HealAffectedTeams.ALLIES ## Which entity teams in relation to who produced this source are affected by this healing.
@export_flags("Player", "Player Attacks", "Enemies", "Enemy Attacks", "Objects", "Terrain", "World Areas", "Layer 8") var scanned_phys_layers: int = 0b00011111 ## The collision mask that this source scans in order to apply affects to.

@export_group("Damage Method")
@export var base_damage: int ## The base numerical amount of damage associated with this effect source.
@export var dmg_affected_stats: DmgAffectedStats ## Which entity stats are affected by this damage source.
@export_range(0.0, 1.0, 0.01, "suffix:%") var crit_chance: float = 0.0 ## The chance the application of damage will be a critial hit.
@export var crit_multiplier: float = 1.5 ## How much stronger critical hits are than normal hits.
@export_range(0.0, 1.0, 0.01, "suffix:%") var armor_penetration: float = 0.0 ## The percent of armor ignored.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var dmg_stun_time: float = 0 ## The amount of time the damage recipient should be stunned for. Note that this only stuns on the first damage tick regardless of DOT settings.
@export_subgroup("Damage Timeline")
@export var dmg_timeline: DmgTimeline ## Whether the damage is instant or over time using damage ticks at intervals.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var dot_total_length: float = 3.0 ## How long the damage over time effect will last.
@export var dot_number_of_ticks: int = 3 ## How many times the damage amount will be applied after this effect source makes contact.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var dot_delay_time: float = 0.0 ## How long before the damage over time starts.

@export_group("Healing Method")
@export var base_healing: int ## The base numerical amount of health associated with this effect source.
@export var heal_affected_stats: HealAffectedStats ## Which entity stats are affected by this healing source.
@export_subgroup("Healing Timeline")
@export var heal_timeline: HealTimeline ## Whether the healing is instant or over time using heal ticks at intervals.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var hot_total_length: float = 3.0 ## How long the healing over time effect will last.
@export var hot_number_of_ticks: int = 3 ## How many times the healing amount will be applied after this effect source makes contact.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var hot_delay_time: float = 0.0 ## How long before the healing over time starts.

@export_group("General")
@export var knockback_force: int = 0 ## The magnitude of knockback applied to the entity receiving this damage.

func _ready() -> void:
	self.area_entered.connect(_on_area_entered)
	monitorable = false
	collision_layer = 0
	collision_mask = scanned_phys_layers

func _on_area_entered(area: Area2D) -> void:
	if area is EffectReceiverComponent:
		area.handle_effect(self)
