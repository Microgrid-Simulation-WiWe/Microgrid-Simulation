class_name ScenarioRegistry
## Findet alle Szenarien: Jede .json direkt in res://scenarios ist ein Szenario.
## Dateien mit "." am Anfang (z. B. .test.json) werden übersprungen, so lässt sich ein Szenario vorerst ausblenden.
## Merkt sich außerdem, welches Szenario gewählt ist.
## Statische Klasse (kein Autoload nötig), lädt beim ersten Zugriff.

const SCENARIOS_DIR := "res://scenarios"

static var _scenarios: Array[ScenarioDefinition] = []
static var _current: ScenarioDefinition
static var _loaded := false


## Alle Szenarien, sortiert nach sort_order.
static func get_all() -> Array[ScenarioDefinition]:
	if not _loaded:
		scan()
	return _scenarios


static func get_by_id(id: StringName) -> ScenarioDefinition:
	for scenario in get_all():
		if scenario.id == id:
			return scenario
	return null


## Das gewählte Szenario, ohne Auswahl das erste. null, wenn es keins gibt.
static func get_current() -> ScenarioDefinition:
	if _current == null and not get_all().is_empty():
		_current = _scenarios[0]
	return _current


## Wählt ein Szenario. Bei unbekannter id bleibt die bisherige Auswahl.
static func select(id: StringName) -> void:
	var scenario := get_by_id(id)
	if scenario == null:
		push_error("ScenarioRegistry: Unbekanntes Szenario '%s'." % id)
		return
	_current = scenario


## Liest alle Szenarien neu ein und hebt die Auswahl auf. Das Verzeichnis ist nur für Tests änderbar.
static func scan(directory := SCENARIOS_DIR) -> void:
	_scenarios.clear()
	_current = null
	_loaded = true
	for file_name in DirAccess.get_files_at(directory):
		if file_name.begins_with(".") or file_name.get_extension() != "json":
			continue
		var scenario := _load_scenario(directory.path_join(file_name), directory)
		if scenario == null:
			continue
		if get_by_id(scenario.id):
			push_error("%s: id '%s' gibt es schon – Szenario wird übersprungen." % [directory.path_join(file_name), scenario.id])
			continue
		_scenarios.append(scenario)
	# Bei gleicher sort_order nach id, damit das erste Szenario auf jedem Rechner dasselbe ist.
	_scenarios.sort_custom(func(a: ScenarioDefinition, b: ScenarioDefinition) -> bool:
		return a.sort_order < b.sort_order or (a.sort_order == b.sort_order and String(a.id) < String(b.id)))


static func _load_scenario(json_path: String, folder: String) -> ScenarioDefinition:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (data is Dictionary):
		push_error("%s: Kein gültiges JSON-Objekt – Szenario wird übersprungen." % json_path)
		return null
	var scenario := ScenarioDefinition.new()
	scenario.load_from_dict(data, folder, json_path)
	return scenario
