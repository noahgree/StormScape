extends Node
class_name ProjectileWeaponFSM
## A finite state machine to control the states of a projectile weapon.

enum State { IDLE, WARMING_UP, FIRING, RELOADING, CHARGING, OVERHEATED }

signal state_changed(new_state: State)

var state: int = State.IDLE:
	set(new_state):
		if state != new_state:
			state = new_state
			state_changed.emit(state)
