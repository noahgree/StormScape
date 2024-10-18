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

var sfx_cache: Dictionary = {} ## The dict of the file paths to all sfx resources, using the sfx name as the key.
var music_cache: Dictionary = {} ## The dict of the file paths to all music resources, using the music name as the key.

#region Setup & Cache
func _ready() -> void:
	if OS.get_unique_id() == "W1RHWL2KQ6": # needed to make audio work on Noah's computer, only affects him
		AudioServer.output_device = "MacBook Pro Speakers (105)" if DebugFlags.AudioFlags.set_debug_output_device else "Default"
	
	_cache_sound_resources(music_resources_folder, music_cache)
	_cache_sound_resources(sfx_resources_folder, sfx_cache)

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
	
	if audio_resource:
		var audio_stream = load(audio_resource.sound_file_path)
		if audio_stream and audio_stream is AudioStream:
			if audio_resource.has_available_stream():
				audio_resource.change_current_count(1)
				var audio_player
				
				if is_2d:
					audio_player = AudioStreamPlayer2D.new()
					audio_player.name = "2D" + audio_resource.name + "@" + str(audio_resource.id)
					audio_resource.on_audio_created()
					audio_player.position = location
					audio_player.attenuation = audio_resource.attentuation_falloff
					audio_player.max_distance = audio_resource.max_distance
				else:
					audio_player = AudioStreamPlayer.new()
					audio_player.name = "GLOBAL" + audio_resource.name + "@" + str(audio_resource.id)
					audio_resource.on_audio_created()
				
				if is_music:
					audio_player.bus = "Music"
				else:
					audio_player.bus = "SFX"
				
				add_child(audio_player)
				audio_player.add_to_group(audio_resource.name)
				
				audio_player.stream = audio_stream
				audio_player.volume_db = audio_resource.volume
				audio_player.pitch_scale = audio_resource.pitch_scale
				audio_player.pitch_scale += randf_range(-audio_resource.pitch_randomness, audio_resource.pitch_randomness)
				
				if audio_resource.should_loop:
					audio_player.finished.connect(func(): _on_looped_audio_end(audio_player))
				else:
					audio_player.finished.connect(func(): _delete_audio_player(audio_player, audio_resource.name))
				
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
func stop_sounds(sound_name: String, number_of_instances_to_stop: int = 0) -> void:
	_destroy_sounds(sound_name, number_of_instances_to_stop, 0.0)

## Fades out all sounds of a sound_name by default, or can stop a specific number if given a value besides 0 
## (up to 10 can actually fade out at once, though).
func fade_out_sounds(sound_name: String, fade_out_time: float = 0.5, number_of_instances_to_stop: int = 0) -> void:
	_destroy_sounds(sound_name, min(10, number_of_instances_to_stop), fade_out_time)

## Handles destroying a certain number of audio stream players for a sound name and optionally fading them out.
func _destroy_sounds(sound_name: String, number_of_instances_to_stop: int, fade_out_time: float) -> void:
	var playing_sounds = _get_playing_sounds(sound_name)
	if number_of_instances_to_stop != 0:
		var validated_number_to_stop: int = min(playing_sounds.size(), number_of_instances_to_stop)
		for i in range(validated_number_to_stop):
			if playing_sounds[i]: # to eliminate data race conditions
				if fade_out_time != 0.0:
					_start_audio_fade_out(playing_sounds[i], sound_name, fade_out_time)
				else:
					playing_sounds[i].stop()
					_delete_audio_player(playing_sounds[i], sound_name)
	else:
		for sound in playing_sounds:
			if sound: # to eliminate data race conditions
				if fade_out_time != 0.0:
					_start_audio_fade_out(sound, sound_name, fade_out_time)
				else:
					sound.stop()
					_delete_audio_player(sound, sound_name)

## Handles fading out the audio player and calling the proper deletion method once the fade out ends.
func _start_audio_fade_out(audio_player, sound_name: String, fade_out_time: float) -> void:
	var tween: Tween = create_tween().bind_node(audio_player)
	tween.tween_property(audio_player, "volume_db", -40.0, fade_out_time)
	tween.finished.connect(func(): _delete_audio_player(audio_player, sound_name))

## Deletes the audio stream player from the tree after removing it from its group and decrementing the 
## audio resource's active count.
func _delete_audio_player(audio_player, sound_name: String) -> void:
	var audio_resource: AudioResource
	if audio_player.bus == "Music":
		audio_resource = music_cache.get(sound_name, null)
	if audio_player.bus == "SFX":
		audio_resource = sfx_cache.get(sound_name, null)
	if audio_resource:
		audio_resource.on_audio_finished()
	
	audio_player.remove_from_group(sound_name)
	audio_player.queue_free()
#endregion
