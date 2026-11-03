class_name ScenarioDefinition
extends Resource
## Steckbrief eines Szenarios. Wird von ScenarioRegistry aus einer JSON-Datei in res://scenarios erzeugt.
## Feldbeschreibung: res://scenarios/_base/scenario_schema.md

@export var id: StringName
@export var display_name: String
@export var sort_order: int
@export_multiline var description: String
## Hinweise für den Spieler, z. B. „viel Sonne“ oder „wenig Wind“.
@export var info: PackedStringArray = []

@export_group("Simulation")
## → GameFlow.round_hours
@export_range(1.0, 168.0, 1.0, "suffix:h") var round_hours := 24.0
## Uhrzeit beim Rundenstart → ClockDisplay.start_hour
@export_range(0.0, 24.0, 0.25, "suffix:h") var start_hour := 12.0
## → EnergyMix.tick_hours
@export_range(0.01, 24.0, 0.01, "suffix:h") var tick_hours := 0.05
## → EnergyMix.ticks_per_second
@export_range(0.0, 60.0, 0.1) var ticks_per_second := 1.0
## → EnergyMix.random_seed
@export var random_seed := 1

@export_group("Erzeuger")
## Typen, die in diesem Szenario nicht gebaut werden dürfen (fehlen in der Inventarleiste).
@export var forbidden_plants: Array[StringName] = []
## Leistungsfaktor je Typ, z. B. 0.5 für Wasserkraft bei niedrigem Wasserstand. Fehlt ein Typ, gilt 1.
## Noch ohne Wirkung.
@export var power_factors: Dictionary[StringName, float] = {}

@export_group("Noch ohne Wirkung")
## Bebaubare Fläche in Rasterfeldern.
@export var build_area := Vector2i(60, 60)
@export var ground_color := Color.GREEN
## Ersetzt das Gras-Mesh.
@export var grass: Mesh
@export var background: Texture2D
## Freie Struktur, wird mit dem Wetter festgelegt.
@export var weather: Dictionary = {}

var _folder := ""
var _source := ""


func is_plant_allowed(plant_id: StringName) -> bool:
	return not forbidden_plants.has(plant_id)


func get_power_factor(plant_id: StringName) -> float:
	return power_factors.get(plant_id, 1.0)


## Füllt den Steckbrief aus dem JSON-Inhalt. Asset-Pfade sind relativ zum Ordner der Datei.
func load_from_dict(data: Dictionary, folder: String, source: String) -> void:
	_folder = folder
	_source = source
	id = StringName(_value(data, "id", source.get_file().get_basename()))
	display_name = _value(data, "display_name", String(id))
	sort_order = int(_value(data, "sort_order", 0))
	description = _value(data, "description", "")
	info = PackedStringArray(_value(data, "info", []))

	round_hours = float(_value(data, "simulation.round_hours", 24.0))
	start_hour = float(_value(data, "simulation.start_hour", 12.0))
	tick_hours = float(_value(data, "simulation.tick_hours", 0.05))
	ticks_per_second = float(_value(data, "simulation.ticks_per_second", 1.0))
	random_seed = int(_value(data, "simulation.random_seed", 1))

	var plants: Dictionary = _value(data, "plants", {})
	for plant_id: String in plants:
		var entry: Variant = plants[plant_id]
		if not (entry is Dictionary):
			push_warning("%s: plants.%s ist kein Objekt – wird ignoriert." % [_source, plant_id])
			continue
		if PlantRegistry.get_by_id(plant_id) == null:
			push_warning("%s: Unbekannter Anlagentyp '%s' unter plants." % [_source, plant_id])
		# Nur ein ausdrückliches false verbietet, fehlend oder null heißt erlaubt.
		if entry.get("allowed") == false:
			forbidden_plants.append(StringName(plant_id))
		if entry.get("power_factor") != null:
			power_factors[StringName(plant_id)] = float(entry["power_factor"])

	var area: Array = _value(data, "build_area", [60, 60])
	build_area = Vector2i(int(area[0]), int(area[1]))
	ground_color = Color.from_string(_value(data, "landscape.ground_color", "#00ff00"), Color.GREEN)
	grass = _load_asset(_value(data, "landscape.grass", "")) as Mesh
	background = _load_asset(_value(data, "landscape.background", "")) as Texture2D
	weather = _value(data, "weather", {})


## Liest ein Feld per Pfad ("simulation.round_hours"). Fehlt es, gibt es eine Warnung und den Standardwert.
## null in der JSON bedeutet "bewusst leer" und liefert still den Standardwert.
func _value(data: Dictionary, path: String, default: Variant) -> Variant:
	var current: Variant = data
	for key in path.split("."):
		if not (current is Dictionary and current.has(key)):
			push_warning("%s: Feld '%s' fehlt – Standardwert %s wird verwendet." % [_source, path, var_to_str(default)])
			return default
		current = current[key]
	return default if current == null else current


## Lädt eine Datei relativ zum Szenario-Ordner. Leer = kein Asset, fehlend = Warnung.
func _load_asset(relative_path: String) -> Resource:
	if relative_path.is_empty():
		return null
	var path := _folder.path_join(relative_path)
	if not ResourceLoader.exists(path):
		push_warning("%s: Asset '%s' nicht gefunden." % [_source, path])
		return null
	return load(path)
