extends Node

enum Teams {
	PLAYER = 1 << 0,
	ENEMY = 1 << 1,
	PASSIVE = 1 << 2 ## Does not heal or damage anything. Just exists. 
}

enum DmgAffectedStats { HEALTH_ONLY, SHIELD_ONLY, SHIELD_THEN_HEALTH, SIMULTANEOUS }
enum HealAffectedStats { HEALTH_ONLY, SHIELD_ONLY, HEALTH_THEN_SHIELD, SIMULTANEOUS }

enum BadEffectAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }
enum GoodEffectAffectedTeams { ENEMIES = 1 << 0, ALLIES = 1 << 1 }

enum EntityStatusEffectType { ## The types of handlers that process additional properties of a status effect.
	NONE, KNOCKBACK, STUN, POISON, REGEN, FROSTBITE, BURNING, TIMESNARE 
	}

const BAD_STATUS_EFFECTS: Array[String] = ["Knockback", "Stun", "Poison", "Frostbite", "Burning", "Confusion", "Slowness", "TimeSnare"]  # FIXME: DELETE THIS AND REDO VIA BOOL
const GOOD_STATUS_EFFECTS: Array[String] = ["Regen", "Untouchable", "Speed"] # FIXME: DELETE THIS AND REDO VIA BOOL
