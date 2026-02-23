extends Resource
class_name StatusEffect
## Defines parameters that can be applied to an entity's stats and health/shield when applied to them.

enum ID { ## The unique ids that represent the types of status effects that can be applied.
	BURNING,
	FROSTBITE,
	POISON,
	SLOWNESS,
	STUN,
	TIME_SNARE,
	CONFUSION,
	KNOCKBACK,
	LIFE_STEAL,
	STORM_SYNDROME,
	REGEN,
	SELF_KNOCKBACK,
	SPEED,
	KINETIC_IMPACT,
	UNTOUCHABLE
}

enum SourceType { ## The different kind of sources that the status effect can come from.
	FROM_WEAPON, ## For any status effect that is the result of being hit by a weapon's hitbox (like projectiles).
	FROM_GROUND_AOE, ## For any status effect that gets applied by walking into a ground AOE like after an explosion.
	FROM_ENVIRONMENT, ## For any status effect coming from the environment, like the cold weather, etc.
	FROM_SELF ## For self effects like when weapons apply effects to the entity while being charged up.
}

@export var id: ID ## What the effect is identified by (doesn't include the level).
@export var source_type: StatusEffect.SourceType ## The source of this status effect to differentiate it and control how its timing may get reset if another of the same effect with a matching source_id comes in.
@export_range(1, 10, 1) var level: int = 1 ## The level of the effect, 1 is the lowest.
@export var is_bad_effect: bool = true ## Whether this should be considered a negative effect. If unchecked, this is considered a good effect. This is used when handling which teams should receive which types of effects related to who sent them.
@export_flags("DynamicEntity:1", "RigidEntity:2", "StaticEntity:4") var affected_entities: int = 0b111
@export var eot: EOTStats ## The effect over time stats used when this applies damage, healing, or stat mods over time.
@export var effects_to_stop: Array[ID] ## The names of other status effects that this status effect should stop and remove from the entity upon being applied.

@export_group("FX")
@export_subgroup("Audio")
@export var audio_to_play: String = "" ## The audio resource to play as a sound effect when hitting an entity.
@export var only_cue_on_player_hit: bool = false ## Whether to only play the associated audio when the status effect is received by the player.
@export_subgroup("Visual")
@export var make_entity_glow: bool = true ## When true, receiving this effect will attempt to update the entity's overlay and floor light color with the color defined below.
@export var spawn_particles: bool = true ## Whether to spawn particles based on the name of this status effect. If the name does not match any valid particle spawners, nothing will happen.
@export var particle_hander_req: String = "" ## Whether the spawning of the particles should be conditional on a handler of the same name being in the entity. If left blank, they don't require a matching handler. Do not include "Handler" in the string. Do not include spaces in the string, either.


## Overrides the default to_string to print a more readable output when included in a print() call.
func _to_string() -> String:
	return ID.keys()[id].capitalize() + "(" + SourceType.keys()[source_type].capitalize() + "): Level " + str(level)

## Gets the full cache key for this status effect, which is an array as [id, source, level].
func get_cache_key() -> Array:
	return [id, source_type, level]

## Gets the key for this status effect, which is an array as [id, source].
func get_key() -> Array:
	return [id, source_type]

## Creates and returns a new EOTI using the EOT stats provided by this status effect.
func create_eoti() -> EOTI:
	var new_eoti: EOTI = EOTI.new(eot)
	return new_eoti
