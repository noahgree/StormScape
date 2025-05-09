extends Resource
class_name StatusEffect
## Base class for all status effects in the game.

@export var id: String ## What the effect is identified by (don't include the level).
@export var source_type: Globals.StatusEffectSourceType ## The source of this status effect to differentiate it and control how its timing may get reset if another of the same effect with a matching source_id comes in.
@export_range(1, 100, 1) var effect_lvl: int = 1 ## The level of the effect, 1 is the lowest.
@export var is_bad_effect: bool = true ## Whether this should be considered a negative effect. If unchecked, this is considered a good effect. This is used when handling which teams should receive which types of effects related to who sent them.
@export_flags("DynamicEntity:1", "RigidEntity:2", "StaticEntity:4") var affected_entities: int = 0b111
@export var effects_to_stop: Array[String] ## The names of other status effects that this status effect should stop and remove from the entity upon being applied.

@export_group("Stat Mods")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var mod_time: float = 5 ## The duration of the mods applied by this effect.
@export var apply_until_removed: bool = false ## If true, these stat mods will ignore their mod time and stay applied until removed.
@export var stat_mods: Array[StatMod] ## The mods applied by this effect. Do not have duplicates in this array.

@export_group("FX")
@export_subgroup("Audio")
@export var audio_to_play: String = "" ## The audio resource to play as a sound effect when hitting an entity.
@export var only_cue_on_player_hit: bool = false ## Whether to only play the associated audio when the status effect is received by the player.
@export_subgroup("Particles")
@export var spawn_particles: bool = true ## Whether to spawn particles based on the name of this status effect. If the name does not match any valid particle spawners, nothing will happen.
@export var particle_hander_req: String = "" ## Whether the spawning of the particles should be conditional on a handler of the same name being in the entity. If left blank, they don't require a matching handler. Do not include "Handler" in the string. Do not include spaces in the string, either.
@export_subgroup("Entity Glow")
@export var make_entity_glow: bool = true ## When true, receiving this effect will attempt to update the entity's overlay and floor light color with the color defined below.


## Overrides the default to_string to print a more readable output when included in a print() call.
func _to_string() -> String:
	return (id + str(effect_lvl))

## Returns a pretty string representation of this status effect.
func get_pretty_string() -> String:
	return (id.capitalize() + " " + str(effect_lvl))

## Returns a string representing the source type of this status effect.
func get_source_type_string() -> String:
	return str(Globals.StatusEffectSourceType.keys()[source_type]).to_lower()

## Gets the full key for this status effect, which is a composite of the effect id and the source type.
func get_full_effect_key() -> String:
	return id + ":" + get_source_type_string()
