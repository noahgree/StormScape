extends Node
## Caches all items from the items folder at game start as an autoload singleton.

var cache : Dictionary = {}

@export_dir var items_folder


func _ready() -> void:
	var folder = DirAccess.open(items_folder)
	folder.list_dir_begin()

	var file_name = folder.get_next()

	while file_name != "":
		cache[file_name] = load(items_folder + "/" + file_name)
		file_name = folder.get_next()

func get_item(item_name) -> Item:
	return cache[item_name + ".tres"]
