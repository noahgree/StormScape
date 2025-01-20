@tool
extends DynamicEntity
class_name Enemy
## Base class for all enemy types. Anything classified as an "enemy" will have the ability to move if needed.
##
## This should not include enemy structures that may fire projectiles, or walls that might deal damage. This is
## only movable enemy characters.
