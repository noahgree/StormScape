extends Node
## Cache autoload for all frequently instantiated FX scenes in the game.

const CONDITION_FX: Dictionary[Condition.ID, PackedScene] = {
	Condition.ID.BURNING : preload("uid://bjkne4ituhs4k"),
	Condition.ID.CONFUSION : preload("uid://ctouq0il4lfrs"),
	Condition.ID.FROSTBITE : preload("uid://l5o46rukviji"),
	Condition.ID.POISON : preload("uid://cymnm25p2dq5e"),
	Condition.ID.REGEN : preload("uid://b2k5opmomkjd5"),
	Condition.ID.SLOWNESS : preload("uid://dubha745om4ng"),
	Condition.ID.SPEED : preload("uid://br2r0c7in46aa"),
	Condition.ID.STORM_SYNDROME : preload("uid://p2nrttxjwqoy"),
	Condition.ID.TIME_SNARE : preload("uid://biy8u12asiyue"),
	Condition.ID.UNTOUCHABLE : preload("uid://clje5sct3up6j")
}


## Gets a condition FX packed scene, or null if it doesn't exist.
func get_condition_fx(condition_id: Condition.ID) -> PackedScene:
	return CONDITION_FX.get(condition_id, null)
