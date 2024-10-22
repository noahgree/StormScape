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

enum EntityStatusEffectType { NONE, KNOCKBACK, STUN, POISON, REGEN, FROSTBITE }
enum EntityStatModType { VITALS, STAMINA, MOVEMENT, DAMAGE, HEALING, KNOCKBACK, STUN, POISON, REGEN, FROSTBITE }
