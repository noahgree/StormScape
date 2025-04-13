extends TextureRect
## Controls the overlay corner tint in response to damage, healing, and being in the storm.

@export var storm_tint_color: Color ## The overlay tint when showing storm fx.
@export var damage_color: Color ## The overlay tint when showing damage fx.
@export var heal_color: Color ## The overlay tint when showing heal fx.
@export var non_storm_scale: float = 1.12 ## How big the overlay should be to cover less of the screen when showing effects.

var tint_tween: Tween ## The tween controlling changing the color and scale of the overlay.
var player_in_storm: bool = false ## Whether the player is currently in the storm.
var showing_effect: bool = false ## Whether we are currently showing an effect from damage or heal.


func _ready() -> void:
	self_modulate.a = 0.0
	SignalBus.player_entered_safe_zone.connect(_on_player_entered_safe_zone)
	SignalBus.player_exited_safe_zone.connect(_on_player_exited_safe_zone)

	if not Globals.player_node:
		await SignalBus.player_ready
	Globals.player_node.health_component.health_changed.connect(_show_hp_change_fx)
	Globals.player_node.health_component.shield_changed.connect(_show_hp_change_fx)

## When the player enters the safe zone and exits the storm, change the fx.
func _on_player_entered_safe_zone() -> void:
	player_in_storm = false
	_change_storm_fx()

## When the player exits the safe zone and enters the storm, change the fx.
func _on_player_exited_safe_zone() -> void:
	player_in_storm = true
	_change_storm_fx()

## If we aren't showing an effect, tween according to whether the player is in the storm or not.
func _change_storm_fx() -> void:
	if showing_effect:
		return
	if tint_tween:
		tint_tween.kill()
	tint_tween = create_tween()

	if not player_in_storm:
		tint_tween.tween_property(self, "self_modulate:a", 0.0, 0.65)
	else:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.15)
		tint_tween.parallel().tween_property(self, "modulate", storm_tint_color, 0.15)

## Starts the tint tweening for an hp change, returning control of the tint back to the _change_form_fx func after.
func _show_hp_change_fx(new_value: int, old_value: int) -> void:
	if tint_tween:
		tint_tween.kill()
	tint_tween = create_tween()

	showing_effect = true
	scale = Vector2(non_storm_scale, non_storm_scale)

	if new_value > old_value:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.06)
		tint_tween.parallel().tween_property(self, "modulate", heal_color, 0.06)
	elif new_value < old_value:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.03)
		tint_tween.parallel().tween_property(self, "modulate", damage_color, 0.03)

	tint_tween.tween_callback(func() -> void: showing_effect = false)
	tint_tween.tween_callback(_change_storm_fx)
	tint_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.06)
