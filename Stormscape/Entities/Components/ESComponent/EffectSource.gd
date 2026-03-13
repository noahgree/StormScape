@abstract
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
	FROM_PROJECTILE, ## For values coming from any normal projectile like a bullet from a sniper or pistol.
	FROM_HITSCAN, ## For values coming from hitscans that must have their beam touch an entity to apply.
	FROM_AOE_EXPLOSION, ## For values coming from AOEs that explode.
	FROM_MAGIC, ## For magic weapons.
	FROM_TOOL, ## For melee weapons like pickaxes and axes that exist primary to interact with the world resources.
	FROM_PHYSICAL_CONTACT, ## For physcial interactions like a punch or running into something with a hitbox attached to the body.
	FROM_COMBAT_MELEE, ## For melee weapons that are primarily damaging weapons like a sword (not tools like the pickaxe).
	FROM_CONSUMABLE, ## For receiving effects from consuming consumables.
	FROM_CONDITION_TICK ## For use with TickES subclasses. [i]Do not choose as source type manually.[/i]
}

enum Tag {
	CUTS_WOOD
}

@export_group("Damage")
@export var base_damage: int ## The base numerical amount of damage associated with this effect source.
@export var object_damage_mult: float = 1.0 ## A multiplier for doing more damage to Static & Rigid entities marked as objects.
@export var dmg_affected_stats: DHHandler.DHType = DHHandler.DHType.SHIELD_THEN_HEALTH ## Which entity stats are affected by this damage source.
@export var dmg_popup_type: EffectPopup.POPUP_TYPE = EffectPopup.POPUP_TYPE.AUTO ## What the popup that results from an entity being hit by this damage should look like it came from.
@export_range(0, 100, 1, "suffix:%") var crit_chance: int = 0 ## The chance the application of damage will be a critial hit.
@export var crit_multiplier: float = 1.5 ## How much stronger critical hits are than normal hits.
@export_range(0, 100, 1, "suffix:%") var armor_penetration: int = 0 ## The percent of armor ignored.
@export_range(0, 100, 1, "suffix:%") var lvl_dmg_scalar: int = 8 ## The percent of base damage that gets added on for every 10 levels, calculated as (((floor(current_lvl / 10) * lvl_dmg_scalar) + 1.0) / 100.0) * base_damage.

@export_group("Healing")
@export var base_healing: int ## The base numerical amount of health associated with this effect source.
@export var heal_affected_stats: DHHandler.DHType = DHHandler.DHType.HEALTH_THEN_SHIELD ## Which entity stats are affected by this healing source.
@export var heal_popup_type: EffectPopup.POPUP_TYPE = EffectPopup.POPUP_TYPE.AUTO ## What the popup that results from an entity being hit by this healing should look like it came from.
@export_range(0, 100, 1, "suffix:%") var lvl_heal_scalar: int = 8 ## The percent of base healing that gets added on for every 10 levels, calculated as [codeblock](((floor(current_lvl / 10) * lvl_heal_scalar) + 1.0) / 100.0) * base_healing[/codeblock].

@export_group("FX")
@export var hit_flash_color: EntitySprite.HitflashColor = EntitySprite.HitflashColor.NORMAL ## The color to flash the hit entity to when hit.
@export var hit_sound: String = "" ## The sound to play when being applied to something.
@export var hit_cam_fx: CamFXResource ## The resource defining how the camera should react to being hit by this.
@export var hit_vfx: PackedScene = null ## The vfx to spawn when being applied to something.
