extends Node
class_name HealthComponent
## A component for handling health and shield for an entity.
## 
## Has functions for handling taking damage and healing.
## This class should always remain agnostic about the entity and the entity's UI it updates.


@export var stats_ui: Control ## The UI that will reflect this component's values.
@export var max_health: int = 100 ## The maximum amount of health the entity can have.
@export var max_shield: int = 100 ## The maximum amount of shield the entity can have.

var health: int: set = _set_health ## The current health of the entity.
var shield: int: set = _set_shield ## The current shield of the entity.


func _ready() -> void: 
	call_deferred("_emit_initial_values")


func take_damage(amount: int) -> void:
	var spillover_damage: int = max(0, amount - shield)
	shield = clampi(shield - amount, 0, max_shield)
	
	if spillover_damage > 0:
		health = clampi(health - spillover_damage, 0, max_health)
		
	# handling death
	if health <= 0:
		if get_parent().has_method("die"):
			get_parent().die()
		else:
			get_parent().queue_free()

func heal(amount: int) -> void:
	var spillover_health: int = max(0, (amount + health) - max_health)
	health = clampi(health + amount, 0, max_health)
	
	if spillover_health > 0:
		shield = clampi(shield + spillover_health, 0, max_shield)


func _emit_initial_values() -> void:
	health = max_health
	shield = max_shield

func set_max_health(new_max_health: int) -> void:
	max_health = new_max_health
	if stats_ui and stats_ui.has_method("on_max_health_changed"):
		stats_ui.on_max_health_changed(max_health)

func set_max_shield(new_max_shield: int) -> void:
	max_shield = new_max_shield
	if stats_ui and stats_ui.has_method("on_max_shield_changed"):
		stats_ui.on_max_shield_changed(max_shield)

func _set_health(new_value: int) -> void:
	health = clampi(new_value, 0, max_health)
	if stats_ui and stats_ui.has_method("on_health_changed"):
		stats_ui.on_health_changed(health)

func _set_shield(new_value: int) -> void:
	shield = clampi(new_value, 0, max_shield)
	if stats_ui and stats_ui.has_method("on_shield_changed"):
		stats_ui.on_shield_changed(shield)
