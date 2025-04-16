extends TextureRect
## Controls the overlay corner tint in response to damage, healing, and being in the storm.

@export var storm_tint_color: Color ## The overlay tint when showing storm fx.
@export var damage_color: Color ## The overlay tint when showing damage fx.
@export var heal_color: Color ## The overlay tint when showing heal fx.
@export var non_storm_scale: float = 1.18 ## How big the overlay should be to cover less of the screen when showing effects.

var tint_tween: Tween ## The tween controlling changing the color and scale of the overlay.
var player_is_sneaking: bool = false ## Whether the player is currently sneaking.
var player_in_safe_zone: bool = false ## Whether the player is currently out of the storm.
var showing_effect: bool = false ## Whether we are currently showing an effect from damage or heal.


func _ready() -> void:
	show()
	SignalBus.player_in_safe_zone_changed.connect(_change_storm_fx)
	SignalBus.player_sneak_state_changed.connect(_change_sneak_fx)

	if not Globals.player_node:
		await SignalBus.player_ready
	Globals.player_node.health_component.health_changed.connect(_show_hp_change_fx)
	Globals.player_node.health_component.shield_changed.connect(_show_hp_change_fx)

	_change_storm_fx(true)

## If we aren't showing any effect, tween according to whether the player is sneaking or not.
func _change_sneak_fx(is_sneaking: bool) -> void:
	player_is_sneaking = is_sneaking
	if showing_effect or not player_in_safe_zone:
		return
	tint_tween = _reset_tween()

	if not player_is_sneaking:
		tint_tween.tween_property(self, "self_modulate:a", 0.0, 0.4)
	else:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.15)
		tint_tween.parallel().tween_property(self, "modulate", Color.BLACK, 0.3)

## If we aren't showing an effect, tween according to whether the player is in the storm or not.
func _change_storm_fx(is_in_safe_zone: bool) -> void:
	player_in_safe_zone = is_in_safe_zone
	if showing_effect:
		return
	tint_tween = _reset_tween()

	if player_in_safe_zone:
		_change_sneak_fx(player_is_sneaking)
	else:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.15)
		tint_tween.parallel().tween_property(self, "modulate", storm_tint_color, 0.15)

## Starts the tint tweening for an hp change, returning control of the tint back to the _change_form_fx func after.
func _show_hp_change_fx(new_value: int, old_value: int) -> void:
	tint_tween = _reset_tween()

	showing_effect = true
	scale = Vector2(non_storm_scale, non_storm_scale)

	if new_value > old_value:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.06)
		tint_tween.parallel().tween_property(self, "modulate", heal_color, 0.06)
	elif new_value < old_value:
		tint_tween.tween_property(self, "self_modulate:a", 1.0, 0.03)
		tint_tween.parallel().tween_property(self, "modulate", damage_color, 0.03)

	tint_tween.tween_callback(func() -> void: showing_effect = false)
	tint_tween.tween_callback(_change_storm_fx.bind(player_in_safe_zone))
	tint_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.06)

## Kills any active tween and returns a new one.
func _reset_tween() -> Tween:
	if tint_tween:
		tint_tween.kill()
	return create_tween()
