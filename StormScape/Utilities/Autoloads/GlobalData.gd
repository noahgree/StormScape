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

enum EntityStatusEffectType { ## The types of handlers that process additional logic of a status effect.
	NONE, KNOCKBACK, STUN, POISON, REGEN, FROSTBITE, BURNING, TIMESNARE 
	}
