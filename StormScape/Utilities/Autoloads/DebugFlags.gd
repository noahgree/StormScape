extends Node
## An autoload singleton file for flagging certain debug features like print statements and audio device switches.


class PrintFlags:
	static var state_machine_swaps: bool = false
	static var stat_mod_changes_during_game: bool = true
	static var stat_mod_changes_on_load: bool = false
	static var current_effect_changes: bool = false
	static var weapon_mod_changes: bool = true
	static var saver_loader_status_changes: bool = true
	static var ammo_updates: bool = false
	static var sounds_starting: bool = false
	static var storm_phases: bool = false
	static var loot_table_updates: bool = false

class PushErrors:
	static var mod_not_in_cache: bool = false ## Anytime a stat mod is applied to a nonexistent stat, push an error. This should be turned off unless debugging a new stat mod, since entities who don't have certain stats like max_speed will always push an error for status effects that try to mod it (but it isn't really an error since it won't affect anything by design).

class MainMenuFlags:
	static var skip_main_menu: bool = false

class AudioFlags:
	static var set_debug_output_device: bool = true

class HotbarFlags:
	static var use_scroll_debounce: bool = true

class Projectiles:
	static var show_collision_points: bool = false
	static var show_homing_rays: bool = false
	static var show_homing_targets: bool = false
	static var show_movement_dir: bool = false
	static var show_hitscan_rays: bool = false
	static var show_aiming_direction: bool = false

class Particles:
	static var show_status_effect_particle_emission_area: bool = false

class OnScreenDebug:
	static var frame_rate: bool = true

class Entity:
	static var show_facing_dir: bool = false
	static var show_movement_vector: bool = true
	static var show_collision_avoidance_rays: bool = false
