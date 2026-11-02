class_name PlantRegistry
## Findet alle Anlagentypen: Jeder Unterordner von res://plants mit einer plant.json ist ein Typ.
## Ordner mit "." am Anfang (z. B. .gas) werden übersprungen, so lässt sich ein Typ vorerst ausblenden.
## Die Kategorien (Reiter der Inventarleiste) stehen in res://plants/categories.json.
## Statische Klasse (kein Autoload nötig), lädt beim ersten Zugriff.

const PLANTS_DIR := "res://plants"
const JSON_FILE := "plant.json"
const CATEGORIES_FILE := "categories.json"

static var _definitions: Array[PlantDefinition] = []
static var _categories: Array[PlantCategory] = []
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


## Alle Kategorien, sortiert nach sort_order (auch leere).
static func get_categories() -> Array[PlantCategory]:
	if not _loaded:
		scan()
	return _categories


static func get_category(id: StringName) -> PlantCategory:
	for category in get_categories():
		if category.id == id:
			return category
	return null


## Alle Typen einer Kategorie, sortiert nach sort_order.
static func get_in_category(category_id: StringName) -> Array[PlantDefinition]:
	var result: Array[PlantDefinition] = []
	for definition in get_all():
		if definition.category == category_id:
			result.append(definition)
	return result


## Typen ohne oder mit unbekannter Kategorie.
static func get_uncategorized() -> Array[PlantDefinition]:
	var result: Array[PlantDefinition] = []
	for definition in get_all():
		if get_category(definition.category) == null:
			result.append(definition)
	return result


## Liest alle plant.json neu ein. Das Verzeichnis ist nur für Tests änderbar.
static func scan(directory := PLANTS_DIR) -> void:
	_definitions.clear()
	_loaded = true
	_load_categories(directory)
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
	for definition in _definitions:
		if not definition.category.is_empty() and get_category(definition.category) == null:
			push_warning("%s: Unbekannte category '%s'." % [definition.folder.path_join(JSON_FILE), definition.category])


## Liest die categories.json. Fehlt sie, gibt es keine Kategorien (alle Typen gelten als ohne Kategorie).
static func _load_categories(directory: String) -> void:
	_categories.clear()
	var path := directory.path_join(CATEGORIES_FILE)
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Array):
		push_error("%s: Keine gültige JSON-Liste – keine Kategorien." % path)
		return
	for entry: Variant in data:
		if not (entry is Dictionary):
			continue
		var category := PlantCategory.new()
		category.load_from_dict(entry, directory)
		_categories.append(category)
	_categories.sort_custom(func(a: PlantCategory, b: PlantCategory) -> bool: return a.sort_order < b.sort_order)


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
