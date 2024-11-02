@icon("res://Utilities/Debug/EditorIcons/audio_manager.svg")
extends Node2D
## A global singleton that caches the location of all audio resources.
##
## Interface with this singleton to play any music or sound effect, optionally providing a location to make it 2d.

@export_dir var music_resources_folder: String ## The folder holding all .tres music files.
@export_dir var sfx_resources_folder: String ## The folder holding all .tres sfx files.
enum SoundCategory { MUSIC, SFX } ## A specifier for determining music vs sfx.
enum SoundSpace { GLOBAL, SPATIAL } ## A specifier for determining global vs spatial (2d) audio.
enum SoundType { MUSIC_GLOBAL, MUSIC_2D, SFX_GLOBAL, SFX_2D } ## Combines the two settings into one for simplicity.

const DISTANCE_FROM_PLAYER_BUFFER: int = 100 ## How far beyond max_distance the player can from the sound origin for a 2d sound to still get created.
const MAX_SPATIAL_POOL_SIZE: int = 12 ## How many 2d audio player nodes can be waiting around in the pool.
const MAX_GLOBAL_POOL_SIZE: int = 15 ## How many global audio player nodes can be waiting around in the pool.
var sfx_cache: Dictionary = {} ## The dict of the file paths to all sfx resources, using the sfx name as the key.
var music_cache: Dictionary = {} ## The dict of the file paths to all music resources, using the music name as the key.

var spatial_pool: Array[AudioStreamPlayer2D] ## The 2d audio players current waiting around in memory.
var global_pool: Array[AudioStreamPlayer] ## The global audio players current waiting around in memory.

#region Setup & Cache
func _ready() -> void:
	if OS.get_unique_id() == "W1RHWL2KQ6": # needed to make audio work on Noah's computer, only affects him.
		var devices = AudioServer.get_output_device_list()
		var macbook_device_index = devices.find("Macbook")
		var macbook_device = devices[macbook_device_index]
		AudioServer.output_device = macbook_device if DebugFlags.AudioFlags.set_debug_output_device else "Default"

	_cache_audio_resources(music_resources_folder, music_cache)
	_cache_audio_resources(sfx_resources_folder, sfx_cache)

	var pool_trim_timer = Timer.new()
	pool_trim_timer.wait_time = 15.0
	pool_trim_timer.autostart = true
	pool_trim_timer.timeout.connect(_trim_pools)
	pool_trim_timer.name = "PoolingTrimDaemon"
	add_child(pool_trim_timer)

## Stores a key-value pair in the appropriate cache dict using the name specified in the sound resource as the key.
## Given a key, the cache created by this method will return a file path to the specified audio name.
func _cache_audio_resources(folder_path: String, cache: Dictionary) -> void:
	var folder = DirAccess.open(folder_path)
	folder.list_dir_begin()

	var file_name = folder.get_next()
	while file_name != "":
		if not folder.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path = folder_path + "/" + file_name
			var resource = load(resource_path)
			if resource and resource is AudioResource:
				var audio_resource = resource as AudioResource
				cache[audio_resource.name] = audio_resource

		file_name = folder.get_next()
	folder.list_dir_end()

## Attempts to retrive an AudioStreamPlayer or AudioStreamPlayer2D from the list of active nodes.
## If there is no active stream under the given name, the function returns null.
func _get_active_audio_players_by_sound_name(sound_name: String) -> Array:
	return get_tree().get_nodes_in_group(sound_name)

## Returns a reference to a cached audio resource if it exists.
func _get_audio_resource_by_type(sound_name: String, type: SoundType) -> AudioResource:
	var audio_resource: AudioResource
	match type:
		SoundType.MUSIC_GLOBAL:
			audio_resource = music_cache.get(sound_name, null)
		SoundType.MUSIC_2D:
			audio_resource = music_cache.get(sound_name, null)
		SoundType.SFX_GLOBAL:
			audio_resource = sfx_cache.get(sound_name, null)
		SoundType.SFX_2D:
			audio_resource = sfx_cache.get(sound_name, null)
	if audio_resource: return audio_resource
	else: return null
#endregion

#region Pooling
## Gets a 2d audio player from the pool or creates one if they are all busy.
func _get_or_create_2d_player() -> AudioStreamPlayer2D:
	if spatial_pool.size() > 0: return spatial_pool.pop_back()
	else: return AudioStreamPlayer2D.new()

## Gets a global audio player from the pool or creates one if they are all busy.
func _get_or_create_global_player() -> AudioStreamPlayer:
	if global_pool.size() > 0: return global_pool.pop_back()
	else: return AudioStreamPlayer.new()

## Puts an audio player back in the pool and removes it from the tree.
func _return_player_to_pool(audio_player) -> void:
	if audio_player.is_inside_tree():
		audio_player.get_parent().remove_child(audio_player)

	if audio_player is AudioStreamPlayer2D:
		spatial_pool.append(audio_player)
	else:
		global_pool.append(audio_player)

## Trims the amount of audio players kept waiting around in the pool when there get to be too many not being used.
func _trim_pools() -> void:
	while spatial_pool.size() > MAX_SPATIAL_POOL_SIZE:
		var player = spatial_pool.pop_back()
		player.queue_free()
	while global_pool.size() > MAX_GLOBAL_POOL_SIZE:
		var player = global_pool.pop_back()
		player.queue_free()
#endregion

#region Starting Sounds
## Called externally to request creating a sound. Lets this singleton manage all starting and stopping logic.
func play_sound(sound_name: String, type: SoundType, location: Vector2 = Vector2.ZERO) -> void:
	_create_audio_player(sound_name, type, location, 0, self)

## Called externally to request creating a sound with a custom fade in time. Lets this singleton manage
## all starting and stopping logic.
func fade_in_sound(sound_name: String, type: SoundType, fade_in_time: float = 0.5,
					location: Vector2 = Vector2.ZERO) -> void:
	_create_audio_player(sound_name, type, location, fade_in_time, self)

## Called externally to not only setup a sound instance by name, but return a reference to its player for external management.
## Fade-in time is optional and if left as 0 will not start with fade.
func play_and_get_sound(sound_name: String, type: SoundType, parent_node: Node,
						fade_in_time: float = 0, location: Vector2 = Vector2.ZERO):
	var audio_player = _create_audio_player(sound_name, type, location, fade_in_time, parent_node)
	return audio_player

## Pulls a sound resource from one of the caches and sends it to be setup if it exists.
func _create_audio_player(sound_name: String, type: SoundType, location: Vector2, fade_in_time: float, parent_node: Node):
	var is_2d: bool = true if type == SoundType.MUSIC_2D or type == SoundType.SFX_2D else false
	var is_music: bool = true if type == SoundType.MUSIC_GLOBAL or type == SoundType.MUSIC_2D else false
	var audio_resource: AudioResource = _get_audio_resource_by_type(sound_name, type)
	if audio_resource == null:
		push_error("Sound name: \"" + sound_name + "\" did not exist as a sound resource in the cache.")
		return
	if is_2d and not _is_close_enough_to_play_2d(audio_resource, location): return

	var audio_stream: AudioStream = _create_stream_resource_from_audio_resource(audio_resource)
	if audio_stream == null: return

	var audio_player = _create_or_restart_audio_player_from_resource(audio_resource, is_2d, is_music, location, fade_in_time)
	if audio_player: audio_player.stream = audio_stream
	else: return

	if parent_node == self:
		_add_audio_player_to_tree_at_node(audio_player, self)
		_start_audio_player_in_tree(audio_player, audio_resource.volume, fade_in_time)
	else:
		_add_audio_player_to_tree_at_node(audio_player, parent_node)
		_start_audio_player_in_tree(audio_player, audio_resource.volume, fade_in_time)
		return audio_player

## Applies the settings from the audio resource to the audio player and returns it if it isn't null.
func _create_or_restart_audio_player_from_resource(audio_resource: AudioResource, is_2d: bool,
												is_music: bool, location: Vector2, fade_in_time: float):
	if audio_resource.has_available_stream():
		audio_resource.increment_current_count()

		var audio_player
		if is_2d:
			audio_player = _get_or_create_2d_player()
			audio_player.name = "2D" + audio_resource.name + "@" + str(audio_resource.id)
			audio_player.position = location
			audio_player.attenuation = audio_resource.attentuation_falloff
			audio_player.max_distance = audio_resource.max_distance
		else:
			audio_player = _get_or_create_global_player()
			audio_player.name = "GLOBAL" + audio_resource.name + "@" + str(audio_resource.id)

		if is_music: audio_player.bus = "Music"
		else: audio_player.bus = "SFX"

		audio_player.add_to_group(audio_resource.name)
		audio_player.set_meta("sound_name", audio_resource.name)

		audio_player.volume_db = audio_resource.volume
		audio_player.pitch_scale = audio_resource.pitch_scale
		audio_player.pitch_scale += randf_range(-audio_resource.pitch_randomness, audio_resource.pitch_randomness)

		if audio_resource.should_loop:
			var callable = Callable(self, "_on_looped_audio_player_end").bind(audio_player)
			audio_player.finished.connect(callable)
			audio_player.set_meta("callable", callable)
		else:
			var callable = Callable(self, "_open_audio_resource_spot").bind(audio_player, true)
			audio_player.finished.connect(callable)
			audio_player.set_meta("callable", callable)

		return audio_player
	elif audio_resource.restart_if_at_limit:
		_restart_sound_by_name_due_to_limit(audio_resource.name, audio_resource.volume, fade_in_time)

## Adds an audio player to the tree as a child of the passed in node.
func _add_audio_player_to_tree_at_node(audio_player, parent_node: Node) -> void:
	parent_node.add_child(audio_player)

## Starts an audio player that is already in the tree, either by fade or immediately.
func _start_audio_player_in_tree(audio_player, volume: float, fade_in_time: float) -> void:
	if fade_in_time > 0:
		_start_audio_player_fade_in(audio_player, volume, fade_in_time)
	else:
		audio_player.play()

## Restarts the first sound in the group belonging to the passed in sound name, fading if necessary.
func _restart_sound_by_name_due_to_limit(sound_name: String, volume: float, fade_in_time: float) -> void:
	var playing_sounds: Array = _get_active_audio_players_by_sound_name(sound_name)
	if playing_sounds[0]:
		playing_sounds[0].stop()
		if fade_in_time != 0.0:
			_start_audio_player_fade_in(playing_sounds[0], volume, fade_in_time)
		else:
			playing_sounds[0].play()

## Picks a random sound from the array in the sound name's resource and creates an audio stream resource from it.
func _create_stream_resource_from_audio_resource(audio_resource: AudioResource) -> AudioStream:
	var sound_file: String = audio_resource.sound_file_paths[randi_range(0, audio_resource.sound_file_paths.size() - 1)]
	return load(sound_file)

## Checks if a 2d sound is close enough to the player to start playing in an effort to save off screen resources.
func _is_close_enough_to_play_2d(audio_resource: AudioResource, location: Vector2) -> bool:
	var distance_to_player: float = GlobalData.player_node.global_position.distance_to(location)
	if distance_to_player > (audio_resource.max_distance + DISTANCE_FROM_PLAYER_BUFFER):
		return false
	else: return true

## Handles fading in the audio player up to the originally specified volume over the specified duration.
func _start_audio_player_fade_in(audio_player, final_volume: float, fade_in_time: float) -> void:
	var tween: Tween = create_tween().bind_node(audio_player)
	audio_player.volume_db = -40.0
	audio_player.play()
	tween.tween_property(audio_player, "volume_db", final_volume, fade_in_time)

## Keeps a looped audio from stopping once it ends.
func _on_looped_audio_player_end(audio_player) -> void:
	audio_player.play()
#endregion

#region Changing Active Sounds
## Changes the volume of all streams of an active sound by either adjusting it by an amount or setting
## it to that amount.
func change_volume_by_sound_name(sound_name: String, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds = _get_active_audio_players_by_sound_name(sound_name)
	for sound in playing_sounds:
		if sound: # to eliminate data race conditions
			if set_to_amount:
				sound.volume_db = clampf(amount, -40, 20)
			else:
				sound.volume_db = clampf(sound.volume_db + amount, -40, 20)

## Changes the pitch of all streams of an active sound by either adjusting it by an amount or setting
## it to that amount.
func change_pitch_by_sound_name(sound_name: String, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds = _get_active_audio_players_by_sound_name(sound_name)
	for sound in playing_sounds:
		if sound: # to eliminate data race conditions
			if set_to_amount:
				sound.pitch_scale = clampf(amount, 0, 4)
			else:
				sound.pitch_scale = clampf(sound.pitch_scale + amount, 0, 4)

## Sets the attenuation max distance for the sound.
func change_attenuation_distance_by_sound_name(sound_name: String, distance: int) -> void:
	var playing_sounds = _get_active_audio_players_by_sound_name(sound_name)
	for sound in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.max_distance = max(1, distance)

## Sets the attenuation falloff exponent for the sound.
func change_attenuation_exponent_by_sound_name(sound_name: String, exponent: float) -> void:
	var playing_sounds = _get_active_audio_players_by_sound_name(sound_name)
	for sound in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.attenuation = max(0, exponent)

## Changes the minimum interval between an audio ending and a spot opening up for when things like footsteps need to occur
## at different rhythms and not in bursts. Resets to default on game load.
func change_sfx_resource_rhythmic_delay(sound_name: String, new_delay: float) -> void:
	var audio_resource: AudioResource = sfx_cache.get(sound_name, null)
	if audio_resource:
		audio_resource.rhythmic_delay = max(0, new_delay)
#endregion

#region Stopping Sounds
## Stops all sounds of a sound_name by default, or can stop a specific number if given a value besides 0.
func stop_sound_by_name(sound_name: String, number_of_instances_to_stop: int = 0) -> void:
	_destroy_sounds_by_sound_name(sound_name, number_of_instances_to_stop, 0.0, false)

## Fades out all sounds of a sound_name by default, or can stop a specific number if given a value besides 0
## (up to 10 can actually fade out at once, though).
func fade_out_sound_by_name(sound_name: String, fade_out_time: float = 0.5,
					number_of_instances_to_stop: int = 0, open_spots_during_fade: bool = false) -> void:
	_destroy_sounds_by_sound_name(sound_name, min(10, number_of_instances_to_stop), fade_out_time, open_spots_during_fade)

## Stops a single sound via stopping its audio player, optionally wide a fade out.
func stop_audio_player(audio_player, fade_out_time: float = 0, open_spot_during_fade: bool = false) -> void:
	if fade_out_time > 0:
		_start_audio_player_fade_out(audio_player, fade_out_time, open_spot_during_fade)
	else:
		_open_audio_resource_spot(audio_player, true)

## Handles destroying a certain number of audio stream players for a sound name and optionally fading them out.
func _destroy_sounds_by_sound_name(sound_name: String, number_of_instances_to_stop: int,
					fade_out_time: float, open_spots_during_fade: bool) -> void:
	var playing_sounds = _get_active_audio_players_by_sound_name(sound_name)
	if number_of_instances_to_stop != 0:
		var validated_number_to_stop: int = min(playing_sounds.size(), number_of_instances_to_stop)
		for i in range(validated_number_to_stop):
			if playing_sounds[i]:
				if fade_out_time > 0:
					_start_audio_player_fade_out(playing_sounds[i], fade_out_time, open_spots_during_fade)
				else:
					_open_audio_resource_spot(playing_sounds[i], true)
	else:
		for player in playing_sounds:
			if player:
				if fade_out_time > 0:
					_start_audio_player_fade_out(player, fade_out_time, open_spots_during_fade)
				else:
					_open_audio_resource_spot(player, true)

## Handles fading out the audio player and calling the proper deletion method once the fade out ends.
## If specified, it can choose to immediately tell the audio resource there is an open spot while fading instead of
## once the fade is over.
func _start_audio_player_fade_out(audio_player, fade_out_time: float, open_spots_during_fade: bool) -> void:
	var tween: Tween = create_tween()

	if open_spots_during_fade:
		_open_audio_resource_spot(audio_player, false)
		tween.finished.connect(func(): _return_audio_player(audio_player))
	else:
		tween.finished.connect(func(): _open_audio_resource_spot(audio_player, true))

	tween.tween_property(audio_player, "volume_db", -40.0, fade_out_time)

## Tell the audio resource that we can open up a spot by decrementing the current count of the sound playing.
## Also removes it from its group.
func _open_audio_resource_spot(audio_player, return_player_to_pool: bool) -> void:
	var sound_name: String = audio_player.get_meta("sound_name")
	_remove_meta_from_audio_player(audio_player)
	audio_player.remove_from_group(sound_name)

	var audio_resource: AudioResource
	if audio_player.bus == "Music":
		audio_resource = music_cache.get(sound_name, null)
	if audio_player.bus == "SFX":
		audio_resource = sfx_cache.get(sound_name, null)
	if audio_resource:
		if audio_resource.rhythmic_delay > 0:
			get_tree().create_timer(audio_resource.rhythmic_delay, false, false, true).timeout.connect(func(): audio_resource.decrement_current_count())
		else:
			audio_resource.decrement_current_count()

	if return_player_to_pool:
		_return_audio_player(audio_player)

## Removes the callable and sound name meta from the audio player.
func _remove_meta_from_audio_player(audio_player) -> void:
	var callable = audio_player.get_meta("callable")
	audio_player.finished.disconnect(callable)
	audio_player.set_meta("callable", null)
	audio_player.set_meta("sound_name", null)

## Returns the audio stream player to its pool after.
func _return_audio_player(audio_player) -> void:
	audio_player.stop()
	_return_player_to_pool(audio_player)
#endregion
