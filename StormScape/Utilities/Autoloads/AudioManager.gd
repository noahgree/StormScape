extends Node2D
## A global singleton that caches the location of all audio resources.
##
## Interface with this singleton to play any music or sound effect, optionally providing a location to make it 2d.

@export_dir var music_resources_folder: String ## The folder holding all .tres music files.
@export_dir var sfx_resources_folder: String ## The folder holding all .tres sfx files.

enum SoundType { ## A specifier for determining music vs sfx and also whether it should be directional or not.
	MUSIC_GLOBAL,
	MUSIC_2D,
	SFX_GLOBAL,
	SFX_2D
}

var sfx_cache: Dictionary = {} ## The dict of the file paths to all sfx resources, using the sfx name as the key.
var music_cache: Dictionary = {} ## The dict of the file paths to all music resources, using the music name as the key.

func _ready() -> void:
	if OS.get_unique_id() == "W1RHWL2KQ6": # needed to make audio work on Noah's computer, only affects him
		AudioServer.output_device = "MacBook Pro Speakers (105)" if DebugFlags.AudioFlags.set_debug_output_device else "Default"
	
	cache_sound_resources(music_resources_folder, music_cache)
	cache_sound_resources(sfx_resources_folder, sfx_cache)

## Stores a key-value pair in the appropriate cache dict using the name specified in the sound resource as the key.
## Given a key, the cache created by this method will return a file path to the specified audio name. 
func cache_sound_resources(folder_path: String, cache: Dictionary) -> void:
	var folder = DirAccess.open(folder_path)
	folder.list_dir_begin()
	
	var file_name = folder.get_next()
	while file_name != "":
		if not folder.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path = folder_path + "/" + file_name
			var resource = load(resource_path)
			if resource and resource is SoundResource:
				var sound_resource = resource as SoundResource
				cache[sound_resource.name] = sound_resource
		
		file_name = folder.get_next()
	folder.list_dir_end()

## Pulls a sound from one of the audio caches and creates it directionally if 2d is specified. 
func create_sound(sound_name: String, type: SoundType, location: Vector2 = Vector2.ZERO) -> void:
	var sound_resource: SoundResource
	var is_2d: bool = false
	var is_music: bool = false
	
	match type:
		SoundType.MUSIC_GLOBAL:
			sound_resource = music_cache.get(sound_name, null)
			is_music = true
		SoundType.MUSIC_2D:
			sound_resource = music_cache.get(sound_name, null)
			is_music = true
			is_2d = true
		SoundType.SFX_GLOBAL:
			sound_resource = sfx_cache.get(sound_name, null)
		SoundType.SFX_2D:
			sound_resource = sfx_cache.get(sound_name, null)
			is_2d = true
	
	if sound_resource:
		var audio_stream = load(sound_resource.sound_file_path)
		if audio_stream and audio_stream is AudioStream:
			if sound_resource.has_available_stream():
				sound_resource.change_current_count(1)
				var audio_player
				
				if is_2d:
					audio_player = AudioStreamPlayer2D.new()
					audio_player.name = "2D" + sound_resource.name
					audio_player.position = location
				else:
					audio_player = AudioStreamPlayer.new()
					audio_player.name = "GLOBAL" + sound_resource.name
				
				if is_music:
					audio_player.bus = "Music"
				else:
					audio_player.bus = "SFX"
				
				add_child(audio_player)
				
				audio_player.stream = audio_stream
				audio_player.volume_db = sound_resource.volume
				audio_player.pitch_scale = sound_resource.pitch_scale
				audio_player.pitch_scale += randf_range(-sound_resource.pitch_randomness, sound_resource.pitch_randomness)
				
				audio_player.finished.connect(sound_resource.on_audio_finished)
				audio_player.finished.connect(audio_player.queue_free)
				
				audio_player.play()
