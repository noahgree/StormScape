extends Node

signal PlayerHealthChanged(new_health: int)
signal PlayerShieldChanged(new_shield: int)
signal PlayerHungerChanged(new_hunger: int)
signal PlayerStaminaChanged(new_stamina: float)
signal PlayerHungerTicksChanged(new_hunger_ticks: float)
signal PlayerStaminaWaitTimerStateChange(wait_time: float, started: bool)
