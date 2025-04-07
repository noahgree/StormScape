extends Node
class_name AudioPreloader
## Attaches to any scene that wants to play audio, preloading the needed sounds if they aren't already in memory upon
## instantiation.

@export var audio_resources: Array[AudioResource] = [] ## Any audio resource that this scene needs to use.

func _ready() -> void:
	if not AudioManager.is_node_ready():
		await AudioManager.ready

	for resource: AudioResource in audio_resources:
		AudioManager.register_scene_audio_resource_use(resource)

func _exit_tree() -> void:
	for resource: AudioResource in audio_resources:
		AudioManager.unregister_scene_audio_resource_use(resource)
