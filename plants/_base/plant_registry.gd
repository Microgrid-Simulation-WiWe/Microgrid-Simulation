class_name PlantRegistry
## Findet alle Anlagentypen: Jeder Unterordner von res://plants mit einer plant.json ist ein Typ.
## Ordner mit "." am Anfang (z. B. .gas) werden übersprungen, so lässt sich ein Typ vorerst ausblenden.
## Statische Klasse (kein Autoload nötig), lädt beim ersten Zugriff.

const PLANTS_DIR := "res://plants"
const JSON_FILE := "plant.json"

static var _definitions: Array[PlantDefinition] = []
static var _loaded := false


## Alle Typen, sortiert nach sort_order.
static func get_all() -> Array[PlantDefinition]:
	if not _loaded:
		scan()
	return _definitions


static func get_by_id(id: StringName) -> PlantDefinition:
	for definition in get_all():
		if definition.id == id:
			return definition
	return null


## Liest alle plant.json neu ein. Das Verzeichnis ist nur für Tests änderbar.
static func scan(directory := PLANTS_DIR) -> void:
	_definitions.clear()
	_loaded = true
	for folder_name in DirAccess.get_directories_at(directory):
		if folder_name.begins_with("."):  # Windows liefert Punkt-Ordner mit, Linux/macOS nicht.
			continue
		var folder := directory.path_join(folder_name)
		var json_path := folder.path_join(JSON_FILE)
		if not FileAccess.file_exists(json_path):
			continue
		var definition := _load_definition(json_path, folder)
		if definition == null:
			continue
		if get_by_id(definition.id):
			push_error("%s: id '%s' gibt es schon – Typ wird übersprungen." % [json_path, definition.id])
			continue
		_definitions.append(definition)
	_definitions.sort_custom(func(a: PlantDefinition, b: PlantDefinition) -> bool: return a.sort_order < b.sort_order)


static func _load_definition(json_path: String, folder: String) -> PlantDefinition:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (data is Dictionary):
		push_error("%s: Kein gültiges JSON-Objekt – Typ wird übersprungen." % json_path)
		return null
	var definition: PlantDefinition
	match data.get("type"):
		"generator":
			definition = GeneratorDefinition.new()
		"storage":
			definition = StorageDefinition.new()
		var unknown:
			push_error("%s: Unbekannter type '%s' – Typ wird übersprungen." % [json_path, unknown])
			return null
	definition.load_from_dict(data, folder, json_path)
	return definition
