extends Resource
class_name CamFXResource
## Defines times and strengths for altering the camera transform during an action such as a gun firing.

@export_group("Shake", "shake")
@export_range(0, 20, 0.01, "hide_slider") var shake_strength: float = 0.0 ## How strong the camera should shake. Anything besides 0 will activate this.
@export_range(0.03, 3, 0.01, "hide_slider") var shake_duration: float = 0.0 ## How long the camera shake should take to decay.
@export var shake_trans_type: Tween.TransitionType = Tween.TransitionType.TRANS_QUINT ## How the effect decay back to normal.
@export var shake_ease_type: Tween.EaseType = Tween.EaseType.EASE_IN ## The direction of the effect decay transition.

@export_group("Freeze", "freeze")
@export_range(0, 1, 0.01, "hide_slider") var freeze_multiplier: float = 1.0 ## How strong the camera should freeze. Anything less than 1.0 will activate this.
@export_range(0.01, 1, 0.001, "hide_slider") var freeze_duration: float = 0.03 ## How long the camera freeze should take to decay.
@export var freeze_instant_change: bool = true ## When false, the freeze effect will tween back to normal. When true, the freeze effect will instantaneously swap back to normal after the elapsed time.
@export var freeze_trans_type: Tween.TransitionType = Tween.TransitionType.TRANS_QUINT ## How the effect decay back to normal.
@export var freeze_ease_type: Tween.EaseType = Tween.EaseType.EASE_IN ## The direction of the effect decay transition.

@export_group("Zoom", "zoom")
@export_range(0.5, 2, 0.001, "hide_slider") var zoom_multiplier: float = 1.0 ## How strongly the camera should zoom. Anything besides 1.0 will activate this.
@export_range(0.04, 2, 0.01, "hide_slider") var zoom_duration: float = 0.04 ## How long the camera zoom should take to decay.
@export var zoom_trans_type: Tween.TransitionType = Tween.TransitionType.TRANS_LINEAR ## How the effect decay back to normal.
@export var zoom_ease_type: Tween.EaseType = Tween.EaseType.EASE_IN_OUT ## The direction of the effect decay transition.

# This section regards variables that only matter when the cam FX are activated as a result of an impact (and included in an effect transform)
@export_group("Impact Logic")
@export_subgroup("Transforms")
@export var trans_player_only: bool = false ## When true and this is activated by an effect receiver, the shake and zoom will only play when the effect source is received by the player.
@export_range(1, 1000, 1, "hide_slider", "or_greater") var trans_max_dist: int = 125 ## How close the player must be from the site of the effect source application to start to feel the cam shake and zoom.
@export var trans_use_falloff: bool = true ## When true, the camera shake and zoom falls off up to the transform_max_dist.
@export_subgroup("Freeze")
@export var freeze_player_only: bool = false ## When true and this is activated by an effect receiver, the freeze will only play when the effect source is received by the player.
@export_range(1, 1000, 1, "hide_slider", "or_greater") var freeze_max_dist: int = 125 ## How close the player must be from the site of the effect source application to start to feel the cam freeze.
@export var freeze_uses_falloff: bool = true ## When true, the camera freeze multiplier falls off up to the freeze_max_dist.


## Easy method for activating all events.
func activate_all() -> void:
	GlobalData.player_camera.start_shake(self)
	GlobalData.player_camera.start_freeze(self)
	GlobalData.player_camera.start_zoom(self)

## Applies the falloffs where needed and activates all the effects.
func apply_falloffs_and_activate_all(is_player: bool, dist_to_player: float = 0) -> void:
	var new_shake_strength: float = shake_strength
	var new_zoom_multiplier: float = zoom_multiplier
	var new_freeze_multiplier: float = freeze_multiplier
	var distance_fraction: float = clampf(dist_to_player / trans_max_dist, 0, 1.0)

	if trans_use_falloff:
		if new_shake_strength > 0: # Can only falloff up to 1/3 of the original strength
			new_shake_strength *= (1 - min(0.33, distance_fraction))
		if new_zoom_multiplier > 1.0: # Can only falloff up to 1/4 of the original multiplier
			var change_portion: float = new_zoom_multiplier - 1.0
			new_zoom_multiplier = 1.0 + (change_portion * max(0.25, 1 - distance_fraction))
		elif new_zoom_multiplier < 1.0:
			var change_portion: float = 1.0 - new_zoom_multiplier
			new_zoom_multiplier = 1.0 - (change_portion * max(0.25, 1 - distance_fraction))
	if (dist_to_player > trans_max_dist) or (not is_player and trans_player_only):
		new_shake_strength = 0
		new_zoom_multiplier = 1.0

	if freeze_uses_falloff: # Can only falloff up to a 3/4 the original multiplier
		var change_portion: float = 1.0 - new_freeze_multiplier
		new_freeze_multiplier = 1.0 - (change_portion * max(0.75, 1 - distance_fraction))
	if (dist_to_player > freeze_max_dist) or (not is_player and freeze_player_only):
		new_freeze_multiplier = 1.0

	var new_cam_fx: CamFXResource = self.duplicate()
	new_cam_fx.shake_strength = new_shake_strength
	new_cam_fx.zoom_multiplier = new_zoom_multiplier
	new_cam_fx.freeze_multiplier = new_freeze_multiplier
	new_cam_fx.activate_all()
