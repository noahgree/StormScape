extends Resource
class_name EffectSource
## A base class for all instances in the game that can apply effects like damage and knockback.
##
## Should be the superclass for all effect sources.
## This contains all the data needed by an esi receiver, and nothing more. Textures, animations, hitboxes, etc.
## should be handled by the producer of this effect source. This is purely data.

enum Type { NORMAL, CHARGE, AOE } ## The kinds of effect sources that can be modified.

enum SourceType {
	FROM_DEFAULT, ## For any effect source that does not come from any of the below types.
	FROM_PROJECTILE, ## For damage coming from any normal projectile like a bullet from a sniper or pistol.
	FROM_EXPLOSION, ## For damage coming from AOEs that explode.
	FROM_GROUND_AOE, ## For damage coming from AOEs that exist on the ground like a poison puddle or aftermath of a molotov.
	FROM_MAGIC, ## For magic weapons.
	FROM_TOOL, ## For melee weapons like pickaxes and axes that exist primary to interact with the world resources.
	FROM_PHYSICAL_CONTACT, ## For physcial interactions like a punch or running into something with a hitbox attached to the body.
	FROM_COMBAT_MELEE, ## For melee weapons that are primarily damaging weapons like a sword (not tools like the pickaxe).
	FROM_CONSUMABLE, ## For receiving effects from consuming consumables.
	FROM_EOT ## For receiving effects from effect over time stats.
}

@export var source_type: SourceType ## A tag used to determine the source of the effect source. See Globals class for details on the tags.
@export var source_tags: Array[String] = [] ## Additional information to pass to whatever receieves this effect source to make sure it should apply.
@export_flags_2d_physics var scanned_phys_layers: int = 0b1101111 ## The collision mask that this source scans in order to apply affects to.
@export var can_hit_self: bool = true ## Whether or not this effect source can be applied to what created it.
@export_flags("Enemies", "Allies") var teams_hit_by_bad: int = Globals.BadAffectedTeams.ENEMIES ## Which entity teams in relation to who produced this source are affected by this damage.
@export_flags("Enemies", "Allies") var teams_hit_by_good: int = Globals.GoodAffectedTeams.ALLIES ## Which entity teams in relation to who produced this source are affected by this healing.
@export var conditions: Array[Condition] ## The array of conditions that can be applied to the receiving entity. [color=salmon] If this is inside EOTStats, leave this array empty! [/color]

@export_group("Base Damage")
@export var base_damage: int: ## The base numerical amount of damage associated with this effect source.
	set(new_value):
		base_damage = max(0, new_value)
@export var object_damage_mult: float = 1.0 ## A multiplier for doing more damage to Static & Rigid entities marked as objects.
@export var dmg_affected_stats: DHHandler.DHType = DHHandler.DHType.SHIELD_THEN_HEALTH ## Which entity stats are affected by this damage source.
@export var dmg_popup_type: EffectPopup.POPUP_TYPE = EffectPopup.POPUP_TYPE.AUTO ## What the popup that results from an entity being hit by this damage should look like it came from.
@export_range(0, 100, 1, "suffix:%") var crit_chance: int = 0 ## The chance the application of damage will be a critial hit.
@export var crit_multiplier: float = 1.5 ## How much stronger critical hits are than normal hits.
@export_range(0, 100, 1, "suffix:%") var armor_penetration: int = 0 ## The percent of armor ignored.
@export_range(0, 100, 1, "suffix:%") var lvl_dmg_scalar: int = 8 ## The percent of base damage that gets added on for every 10 levels, calculated as (((floor(current_lvl / 10) * lvl_dmg_scalar) + 1.0) / 100.0) * base_damage.

@export_group("Base Healing")
@export var base_healing: int: ## The base numerical amount of health associated with this effect source.
	set(new_value):
		base_healing = max(0, new_value)
@export var heal_affected_stats: DHHandler.DHType = DHHandler.DHType.HEALTH_THEN_SHIELD ## Which entity stats are affected by this healing source.
@export var heal_popup_type: EffectPopup.POPUP_TYPE = EffectPopup.POPUP_TYPE.AUTO ## What the popup that results from an entity being hit by this healing should look like it came from.
@export_range(0, 100, 1, "suffix:%") var lvl_heal_scalar: int = 8 ## The percent of base healing that gets added on for every 10 levels, calculated as [codeblock](((floor(current_lvl / 10) * lvl_heal_scalar) + 1.0) / 100.0) * base_healing[/codeblock].

@export_group("FX")
@export var impact_cam_fx: CamFXResource ## The resource defining how the camera should react to firing.
@export var impact_vfx: PackedScene = null ## The vfx to spawn when impacting something.
@export var impact_sound: String = "" ## The sound to play when impacting something.
@export var hit_flash_color: Color = Color(1, 1, 1, 0.6) ## The color to flash the hit entity to on being hit.
