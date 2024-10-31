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

const MAX_SPATIAL_POOL_SIZE: int = 12 ## How many 2d audio player nodes can be waiting around in the pool.
const MAX_GLOBAL_POOL_SIZE: int = 15 ## How many global audio player nodes can be waiting around in the pool.
var sfx_cache: Dictionary = {} ## The dict of the file paths to all sfx resources, using the sfx name as the key.
var music_cache: Dictionary = {} ## The dict of the file paths to all music resources, using the music name as the key.

var spatial_pool: Array[AudioStreamPlayer2D] ## The 2d audio players current waiting around in memory.
var global_pool: Array[AudioStreamPlayer] ## The global audio players current waiting around in memory.

#region Setup & Cache
func _ready() -> void:
	if OS.get_unique_id() == "W1RHWL2KQ6": # needed to make audio work on Noah's computer, only affects him
		AudioServer.output_device = "MacBook Pro Speakers (75)" if DebugFlags.AudioFlags.set_debug_output_device else "Default"

	_cache_sound_resources(music_resources_folder, music_cache)
	_cache_sound_resources(sfx_resources_folder, sfx_cache)

	var pool_trim_timer = Timer.new()
	pool_trim_timer.wait_time = 15.0
	pool_trim_timer.autostart = true
	pool_trim_timer.timeout.connect(_trim_pools)
	pool_trim_timer.name = "PoolingTrimDaemon"
	add_child(pool_trim_timer)

## Stores a key-value pair in the appropriate cache dict using the name specified in the sound resource as the key.
## Given a key, the cache created by this method will return a file path to the specified audio name.
func _cache_sound_resources(folder_path: String, cache: Dictionary) -> void:
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
func _get_playing_sounds(sound_name: String) -> Array:
	return get_tree().get_nodes_in_group(sound_name)
#endregion

#region Pooling
## Gets a 2d audio player from the pool or creates one if they are all busy.
func _get_or_create_2d_player() -> AudioStreamPlayer2D:
	if spatial_pool.size() > 0:
		return spatial_pool.pop_back()
	else:
		return AudioStreamPlayer2D.new()

## Gets a global audio player from the pool or creates one if they are all busy.
func _get_or_create_global_player() -> AudioStreamPlayer:
	if global_pool.size() > 0:
		return global_pool.pop_back()
	else:
		return AudioStreamPlayer.new()

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
## Called externally to request creating a sound.
func play_sound(sound_name: String, type: SoundType, location: Vector2 = Vector2.ZERO) -> void:
	_create_sound(sound_name, type, location, 0.0)

## Called externally to request creating a sound with a custom fade in time.
func fade_in_sound(sound_name: String, type: SoundType, fade_in_time: float = 0.5,
					location: Vector2 = Vector2.ZERO) -> void:
	_create_sound(sound_name, type, location, fade_in_time)

## Pulls a sound from one of the audio caches and creates it directionally if 2d is specified.
func _create_sound(sound_name: String, type: SoundType, location: Vector2, fade_in_time: float) -> void:
	var audio_resource: AudioResource
	var is_2d: bool = false
	var is_music: bool = false

	match type:
		SoundType.MUSIC_GLOBAL:
			audio_resource = music_cache.get(sound_name, null)
			is_music = true
		SoundType.MUSIC_2D:
			audio_resource = music_cache.get(sound_name, null)
			is_music = true
			is_2d = true
		SoundType.SFX_GLOBAL:
			audio_resource = sfx_cache.get(sound_name, null)
		SoundType.SFX_2D:
			audio_resource = sfx_cache.get(sound_name, null)
			is_2d = true

	if is_2d and (audio_resource.max_distance < (SaverLoader.player_node.global_position.distance_to(location))):
		return

	if audio_resource:
		var sound_to_load: String = audio_resource.sound_file_paths[randi_range(0, audio_resource.sound_file_paths.size() - 1)]
		var audio_stream = load(sound_to_load)
		if audio_stream and audio_stream is AudioStream:
			if audio_resource.has_available_stream():
				audio_resource.change_current_count(1)
				var audio_player

				if is_2d:
					audio_player = _get_or_create_2d_player()
					audio_player.name = "2D" + audio_resource.name + "@" + str(audio_resource.id)
					audio_player.position = location
					audio_player.attenuation = audio_resource.attentuation_falloff
					audio_player.max_distance = audio_resource.max_distance
					audio_resource.on_audio_created()
				else:
					audio_player = _get_or_create_global_player()
					audio_player.name = "GLOBAL" + audio_resource.name + "@" + str(audio_resource.id)
					audio_resource.on_audio_created()

				if is_music:
					audio_player.bus = "Music"
				else:
					audio_player.bus = "SFX"

				if not audio_player.is_inside_tree():
					add_child(audio_player)
				audio_player.add_to_group(audio_resource.name)

				audio_player.stream = audio_stream
				audio_player.volume_db = audio_resource.volume
				audio_player.pitch_scale = audio_resource.pitch_scale
				audio_player.pitch_scale += randf_range(-audio_resource.pitch_randomness, audio_resource.pitch_randomness)

				if audio_resource.should_loop:
					var callable = Callable(self, "_on_looped_audio_end").bind(audio_player)
					audio_player.finished.connect(callable)
					audio_player.set_meta("callable", callable)
				else:
					var callable = Callable(self, "_open_audio_resource_spot").bind(audio_player, audio_resource.name, true)
					audio_player.finished.connect(callable)
					audio_player.set_meta("callable", callable)

				if fade_in_time != 0.0:
					_start_audio_fade_in(audio_player, audio_resource.volume, fade_in_time)
				else:
					audio_player.play()
			elif audio_resource.restart_if_at_limit:
				var playing_sounds: Array = _get_playing_sounds(sound_name)
				if playing_sounds[0]:
					playing_sounds[0].stop()
					if fade_in_time != 0.0:
						_start_audio_fade_in(playing_sounds[0], audio_resource.volume, fade_in_time)
					else:
						playing_sounds[0].play()

## Handles fading in the audio player up to the originally specified volume over the specified duration.
func _start_audio_fade_in(audio_player, final_volume: float, fade_in_time: float) -> void:
	var tween: Tween = create_tween().bind_node(audio_player)
	audio_player.volume_db = -40.0
	audio_player.play()
	tween.tween_property(audio_player, "volume_db", final_volume, fade_in_time)

## Keeps a looped audio from stopping once it ends.
func _on_looped_audio_end(audio_player) -> void:
	audio_player.play()
#endregion

#region Changing Active Sounds
## Changes the volume of all streams of an active sound by either adjusting it by an amount or setting
## it to that amount.
func change_volume(sound_name: String, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds = _get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound: # to eliminate data race conditions
			if set_to_amount:
				sound.volume_db = clampf(amount, -40, 20)
			else:
				sound.volume_db = clampf(sound.volume_db + amount, -40, 20)

## Changes the pitch of all streams of an active sound by either adjusting it by an amount or setting
## it to that amount.
func change_pitch(sound_name: String, amount: float, set_to_amount: bool = false) -> void:
	var playing_sounds = _get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound: # to eliminate data race conditions
			if set_to_amount:
				sound.pitch_scale = clampf(amount, 0, 4)
			else:
				sound.pitch_scale = clampf(sound.pitch_scale + amount, 0, 4)

## Sets the attenuation max distance for the sound.
func change_attenuation_distance(sound_name: String, distance: int) -> void:
	var playing_sounds = _get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.max_distance = max(1, distance)

## Sets the attenuation falloff exponent for the sound.
func change_attenuation_exponent(sound_name: String, exponent: float) -> void:
	var playing_sounds = _get_playing_sounds(sound_name)
	for sound in playing_sounds:
		if sound is AudioStreamPlayer2D:
			sound.attenuation = max(0, exponent)
#endregion

#region Stopping Sounds
## Stops all sounds of a sound_name by default, or can stop a specific number if given a value besides 0.
func stop_sound(sound_name: String, number_of_instances_to_stop: int = 0) -> void:
	_destroy_sounds(sound_name, number_of_instances_to_stop, 0.0, false)

## Fades out all sounds of a sound_name by default, or can stop a specific number if given a value besides 0
## (up to 10 can actually fade out at once, though).
func fade_out_sounds(sound_name: String, fade_out_time: float = 0.5,
					number_of_instances_to_stop: int = 0, open_spots_during_fade: bool = false) -> void:
	_destroy_sounds(sound_name, min(10, number_of_instances_to_stop), fade_out_time, open_spots_during_fade)

## Handles destroying a certain number of audio stream players for a sound name and optionally fading them out.
func _destroy_sounds(sound_name: String, number_of_instances_to_stop: int,
					fade_out_time: float, open_spots_during_fade: bool) -> void:
	var playing_sounds = _get_playing_sounds(sound_name)
	if number_of_instances_to_stop != 0:
		var validated_number_to_stop: int = min(playing_sounds.size(), number_of_instances_to_stop)
		for i in range(validated_number_to_stop):
			if playing_sounds[i]:
				if fade_out_time != 0.0:
					_start_audio_fade_out(playing_sounds[i], sound_name, fade_out_time, open_spots_during_fade)
				else:
					_open_audio_resource_spot(playing_sounds[i], sound_name, true)
	else:
		for sound in playing_sounds:
			if sound:
				if fade_out_time != 0.0:
					_start_audio_fade_out(sound, sound_name, fade_out_time, open_spots_during_fade)
				else:
					_open_audio_resource_spot(sound, sound_name, true)

## Handles fading out the audio player and calling the proper deletion method once the fade out ends.
## If specified, it can choose to immediately tell the audio resource there is an open spot while fading instead of
## once the fade is over.
func _start_audio_fade_out(audio_player, sound_name: String, fade_out_time: float, open_spots_during_fade: bool) -> void:
	var tween: Tween = create_tween().bind_node(audio_player)
	tween.tween_property(audio_player, "volume_db", -40.0, fade_out_time)
	if open_spots_during_fade:
		_open_audio_resource_spot(audio_player, sound_name, false)
		tween.finished.connect(func(): _return_audio_player(audio_player, sound_name))
	else:
		tween.finished.connect(func(): _open_audio_resource_spot(audio_player, sound_name, true))

## Tell the audio resource that we can open up a spot by decrementing the current count of the sound playing.
## Then it removes it from its  group.
func _open_audio_resource_spot(audio_player, sound_name: String, return_player_to_pool: bool) -> void:
	_remove_callable_from_signal(audio_player)
	var audio_resource: AudioResource
	if audio_player.bus == "Music":
		audio_resource = music_cache.get(sound_name, null)
	if audio_player.bus == "SFX":
		audio_resource = sfx_cache.get(sound_name, null)
	if audio_resource:
		if audio_resource.rythmic_delay > 0:
			await get_tree().create_timer(audio_resource.rythmic_delay, false, false, true).timeout
		audio_resource.on_audio_finished()

	if return_player_to_pool:
		_return_audio_player(audio_player, sound_name)

## Returns the audio stream player to its pool after removing it from its group.
func _return_audio_player(audio_player, sound_name: String) -> void:
	audio_player.stop()
	audio_player.remove_from_group(sound_name)
	_return_player_to_pool(audio_player)

## Removes the callable from the "finished" signal from the audio player.
func _remove_callable_from_signal(audio_player) -> void:
	if audio_player.has_meta("callable"): # so when we use it next time it doesn't have its old signal connections
		var callable = audio_player.get_meta("callable")
		audio_player.finished.disconnect(callable)
		audio_player.set_meta("callable", null)
#endregion
