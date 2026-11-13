class_name ConsumerRegistry
extends RefCounted
## Lädt alle Verbraucher aus res://consumers/*.json (einmal, danach aus dem Cache).

const FOLDER := "res://consumers"
static var _profiles: Dictionary = {}
static var _loaded := false


static func get_by_id(id: String) -> ConsumerProfile:
	if not _loaded:
		_scan()
	return _profiles.get(id)


static func _scan() -> void:
	_loaded = true
	for file in DirAccess.get_files_at(FOLDER):
		if not file.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOLDER.path_join(file)))
		if data is Dictionary and data.has("id"):
			_profiles[data["id"]] = ConsumerProfile.from_dict(data)
		else:
			push_warning("Verbraucher %s ist ungültig." % file)
