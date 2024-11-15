extends Resource
class_name StatusEffect
## Base class for all status effects in the game.

@export var effect_name: String ## What the effect title is without the level attached.
@export_range(1, 100, 1) var effect_lvl: int = 1 ## The level of the effect, 1 is the lowest.
@export var is_bad_effect: bool = true ## Whether this should be considered a negative effect. If unchecked, this is considered a good effect. This is used when handling which teams should receive which types of effects related to who sent them.
@export var effects_to_stop: Array[String] ## The names of other status effects that this status effect should stop and remove from the entity upon being applied.

@export_group("Audio")
@export var audio_to_play: String = "" ## The audio resource to play as a sound effect when hitting an entity.
@export var only_cue_on_player_hit: bool = false ## Whether to only play the associated audio when the status effect is received by the player.

@export_group("Stat Mods")
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var mod_time: float = 5 ## The duration of the mods applied by this effect.
@export var stat_mods: Array[EntityStatMod] ## The mods applied by this effect. Do not have duplicates in this array.

var movement_direction: Vector2
var contact_position: Vector2
var is_source_moving_type: bool = false
