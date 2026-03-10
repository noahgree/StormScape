@tool
extends Resource
class_name Condition
## Defines parameters that can be applied to an entity's stats and health/shield when applied to them.

enum ID { ## The unique ids that represent the types of conditions that can be applied.
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
	UNTOUCHABLE,
	NULL ## Value corresponding to no condition. Used in certain handling functions.
}

enum SourceType { ## The different kind of sources that the condition can come from.
	FROM_WEAPON, ## For any condition that is the result of being hit by a weapon's hitbox (like projectiles).
	FROM_GROUND_AOE, ## For any condition that gets applied by walking into a ground AOE like after an explosion.
	FROM_ENVIRONMENT, ## For any condition coming from the environment, like the cold weather, etc.
	FROM_SELF ## For self conditions like when weapons apply conditions to the entity while being charged up.
}

enum Goodness { GOOD, BAD } ## Splits up what is considered good and bad conditions.

@export var id: ID ## What the effect is identified by (doesn't include the level).
@export var source_type: SourceType ## The source of this condition to differentiate it and control how its timing may get reset if another of the same effect with a matching source_id comes in.
@export_range(1, 10, 1) var level: int = 1 ## The level of the condition, 1 is the lowest.
@export var goodness: Goodness = Goodness.GOOD ## Whether this should be considered a negative condition. This is used when handling which teams should receive which types of conditions related to who sent them.
@export_flags("DynamicEntity:1", "RigidEntity:2", "StaticEntity:4") var affected_entities: int = 0b111
@export var conditions_to_stop: Array[ID] ## The names of other conditions that this condition should stop and remove from the entity upon being applied.
@export var eot_stats: EOTStats: set = _check_ticks_array ## The effect over time stats used when this applies damage, healing, or stat mods over time.

@export_group("FX")
@export var audio_to_play: String = "" ## The audio resource to play as a sound effect when hitting an entity.
@export var only_cue_on_player_hit: bool = false ## Whether to only play the associated audio when the condition is received by the player.
@export var make_entity_glow: bool = true ## When true, receiving this effect will attempt to update the entity's overlay and floor light color based on the condition ID.
@export var spawn_particles: bool = true ## Whether to spawn particles based on the ID of this condition. If the condition does not have an associated particle spawner, nothing will happen.


## Overrides the default to_string to print a more readable output when included in a print() call.
func _to_string() -> String:
	return ID.keys()[id].capitalize() + ":" + str(level) + " (" + SourceType.keys()[source_type].capitalize() + ")"

## Gets the full cache key for this condition, which is an array as [id, source, level].
func get_cache_key() -> Array:
	return [id, source_type, level]

## Gets the key for this condition, which is an array as [condition_id, source_type].
func get_key() -> Array:
	return [id, source_type]

## Called when received by the conditions component, as long as it makes it past the untouchable check and the
## teams check.
func on_received_regardless_of_level(_esi: ESI, _entity: Entity) -> void:
	pass

#region Debug
## Setter for the ticks array to make sure each Effect Source uses the right source type.
func _check_ticks_array(new_eot_stats: EOTStats) -> void:
	eot_stats = new_eot_stats
	for effect_source: EffectSource in eot_stats.ticks_array:
		if effect_source.source_type != EffectSource.SourceType.FROM_EOT:
			push_error(str(self) + " has an effect source in its eot_stats that don't identify their source as FROM_EOTI. This will cause issues.")
#endregion
