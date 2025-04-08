extends Node
class_name AudioPreloader
## Attaches to any scene that wants to play audio, preloading the needed sounds if they aren't already in memory upon
## instantiation.

@export var scene_audio: Array[AudioResource] = [] ## Any audio resource that this scene needs to use.


func _ready() -> void:
	register_sounds_from_resources(scene_audio)

func _exit_tree() -> void:
	unregister_sounds_from_resources(scene_audio)

static func register_sounds_from_resources(resource_array: Array[AudioResource]) -> void:
	for resource: AudioResource in resource_array:
		AudioManager.register_scene_audio_resource_use(resource.id)

static func unregister_sounds_from_resources(resource_array: Array[AudioResource]) -> void:
	for resource: AudioResource in resource_array:
		AudioManager.unregister_scene_audio_resource_use(resource.id)

static func register_sounds_from_ids(id_array: Array[StringName]) -> void:
	for id: StringName in id_array:
		if id != "":
			AudioManager.register_scene_audio_resource_use(id)

static func unregister_sounds_from_ids(id_array: Array[StringName]) -> void:
	for id: StringName in id_array:
		if id != "":
			AudioManager.unregister_scene_audio_resource_use(id)
