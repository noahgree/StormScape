@icon("res://Utilities/Debug/EditorIcons/weapon_mod.svg")
extends ItemResource
class_name WeaponMod
## Class for all weapon mods in the game.

@export_group("General")
@export var allowed_proj_wpns: Array[ProjWeaponResource.ProjWeaponType] = GlobalData.all_proj_weapons ## The allowed types of projectile weapons that can have this mod attached. Has all types allowed by default.
@export var allowed_melee_wpns: Array[MeleeWeaponResource.MeleeWeaponType] = GlobalData.all_melee_wpns ## The allowed types of melee weapons that can have this mod attached. Has all types allowed by default.
@export var icon: Texture2D ## The icon for this weapon mod.

@export_group("Stat & Effect Mods")
@export var wpn_stat_mods: Array[StatMod] ## The stat modifiers applied by this mod. Do not have duplicates in this array.
@export var status_effects: Array[StatusEffect] ## The status effects to add to the weapon's effect source status effects.
@export var charge_status_effects: Array[StatusEffect] ## The status effects to add to the weapon's charge effect source status effects.

@export_group("FX")
@export var equipping_audio: String = "" ## The audio resource to play as a sound effect when adding this mod to a weapon.
@export var removal_audio: String = "" ## The audio resource to play as a sound effect when removing this mod from a weapon.


## Intended to be overridden. This is called immediately after this mod is added.
func on_added(_weapon_stats: WeaponResource, _source_entity: PhysicsBody2D) -> void:
	pass

## Intended to be overridden. This is called immediately after this mod is removed.
func on_removal(_weapon_stats: WeaponResource, _source_entity: PhysicsBody2D) -> void:
	pass
