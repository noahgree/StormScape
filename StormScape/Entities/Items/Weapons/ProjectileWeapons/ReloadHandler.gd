extends Node
class_name ReloadHandler

signal reload_started
signal reload_finished

var weapon: ProjectileWeapon
var anim_player: AnimationPlayer


func initialize(new_weapon: ProjectileWeapon) -> void:
	weapon = new_weapon
	anim_player = weapon.anim_player

func attempt_reload() -> void:
	# If we already have a full mag or there is no more reserve ammo in the inventory to reload with, return
	if _mag_is_full() or _get_more_reload_ammo(1, false) == 0:
		return
	reload_started.emit()

	match weapon.stats.reload_type:
		"Magazine":
			_start_magazine_reload()
		"Single":
			_start_single_reload_delay()

func _start_magazine_reload() -> void:
	var reload_time: float = weapon.stats.s_mods.get_stat("mag_reload_time")
	_start_reload_animation("mag_reload", reload_time)

func _start_single_reload_delay() -> void:
	var delay_time: float = weapon.stats.before_single_reload_time
	if delay_time <= 0:
		_start_single_reload()
	else:
		_start_reload_animation("before_single_reload", delay_time)

func _start_single_reload() -> void:
	var reloads_needed: int = _get_needed_single_reloads_count()
	var reload_time: float = weapon.stats.s_mods.get_stat("single_proj_reload_time")
	if reloads_needed > 1:
		_start_reload_animation("single_reload", reload_time)
	elif reloads_needed == 1:
		var anim_name: String = "final_single_reload"
		if not anim_player.has_animation(anim_name):
			anim_name = "single_reload"
		_start_reload_animation(anim_name, reload_time)
	else:
		reload_finished.emit()

func _mag_is_full() -> bool:
	return weapon.stats.ammo_in_mag >= weapon.stats.s_mods.get_stat("mag_size")

## Searches through the source entity's inventory for more ammo to fill the magazine.
## Can optionally be used to only check for ammo when told not to take from the inventory when found.
func _get_more_reload_ammo(max_amount_needed: int, take_from_inventory: bool = true) -> int:
	if weapon.stats.ammo_type == ProjWeaponResource.ProjAmmoType.NONE:
		return max_amount_needed
	else:
		return weapon.source_entity.inv.get_more_ammo(max_amount_needed, take_from_inventory, weapon.stats.ammo_type)

func _start_reload_animation(anim_name: String, duration: float) -> void:
	if anim_player.current_animation == "overheat":
		weapon.reset_animation_state()

	anim_player.speed_scale = 1.0 / duration
	weapon.source_entity.hands.off_hand_sprite.self_modulate.a = 0.0
	anim_player.animation_finished.connect(_on_reload_animation_finished, CONNECT_ONE_SHOT)
	anim_player.play(anim_name)

func _on_reload_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"mag_reload":
			_complete_mag_reload()
		"before_single_reload":
			_start_single_reload()
		"single_reload":
			_complete_single_reload()
		"final_single_reload":
			_complete_single_reload()

func _complete_mag_reload() -> void:
	var mag_size: int = int(weapon.stats.s_mods.get_stat("mag_size"))
	var ammo_needed: int = mag_size - weapon.stats.ammo_in_mag
	var ammo_available: int = _get_more_reload_ammo(ammo_needed)
	_update_mag_ammo(weapon.stats.ammo_in_mag + ammo_available)
	reload_finished.emit()

func _complete_single_reload() -> void:
	var mag_size: int = int(weapon.stats.s_mods.get_stat("mag_size"))
	var ammo_needed: int = mag_size - weapon.stats.ammo_in_mag
	var reload_quantity: int = int(weapon.stats.s_mods.get_stat("single_reload_quantity"))
	var ammo_available: int = _get_more_reload_ammo(min(ammo_needed, reload_quantity))
	_update_mag_ammo(weapon.stats.ammo_in_mag + ammo_available)

	if ammo_available <= 0:
		reload_finished.emit()
		return

	_start_single_reload()

func _get_needed_single_reloads_count() -> int:
	var mag_size: int = int(weapon.stats.s_mods.get_stat("mag_size"))
	var ammo_needed: int = mag_size - weapon.stats.ammo_in_mag
	var reload_quantity: int = int(weapon.stats.s_mods.get_stat("single_reload_quantity"))
	var reloads_needed: int = ceili(float(ammo_needed) / float(reload_quantity))
	return reloads_needed

func _update_mag_ammo(new_amount: int) -> void:
	weapon.stats.ammo_in_mag = new_amount
	_update_ammo_ui()

## Updates the ammo UI with the ammo in the magazine, assuming this is being used by a Player and the weapon uses
## consumable ammo.
func _update_ammo_ui() -> void:
	if weapon.ammo_ui == null or weapon.stats.hide_ammo_ui:
		return

	var count: int = -1
	match weapon.stats.ammo_type:
		ProjWeaponResource.ProjAmmoType.SELF:
			if weapon.source_slot.item == null:
				count = -1
			else:
				count = weapon.source_slot.item.quantity
		ProjWeaponResource.ProjAmmoType.STAMINA:
			count = weapon.source_entity.stamina_component.stamina
		_:
			count = weapon.stats.ammo_in_mag

	weapon.ammo_ui.update_mag_ammo(count)
	weapon.ammo_ui.calculate_inv_ammo()
