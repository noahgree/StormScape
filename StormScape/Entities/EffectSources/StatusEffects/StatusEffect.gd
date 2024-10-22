extends Resource
class_name StatusEffect
## Base class for all status effects in the game.

@export var handler_type: EnumUtils.EntityStatusEffectType = EnumUtils.EntityStatusEffectType.NONE ## What kind of handler node should process this effect.
@export var effect_name: String ## What the effect title is without the level attached.
@export var effect_lvl: int ## The level of the effect, 1 is the lowest.
@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var effect_mods_time: float = 5 ## The duration of the mods applied by this effect.
@export var stat_mods: Array[EntityStatMod] ## The mods applied by this effect. Do not have duplicates in this array.

var movement_direction: Vector2
var contact_position: Vector2
var is_source_moving_type: bool = false
