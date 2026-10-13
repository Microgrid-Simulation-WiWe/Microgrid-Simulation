@abstract
class_name PlantDefinition
extends Resource
## Steckbrief eines Anlagentyps. Wird von PlantRegistry aus der plant.json im Typ-Ordner erzeugt.
## Feldbeschreibung: res://plants/_base/plant_schema.md

@export var id: StringName
@export var display_name: String
@export var sort_order: int
@export var folder: String

@export_group("Bau")
@export var build_cost: int
@export var area_usage := Vector2i.ONE

@export_group("Leistung")
@export_range(0.0, 1000.0, 0.1, "or_greater", "suffix:MW") var unit_power_mw: float
@export_range(0.0, 100.0, 0.1, "suffix:%/Tick") var ramp_per_tick := 100.0

@export_group("Assets")
@export var icon: Texture2D
@export var building_scene: PackedScene
@export var model: PackedScene
@export var textures: Dictionary[String, Texture2D] = {}
@export var animation: StringName
@export var sounds: Dictionary[String, AudioStream] = {}
@export var effects: Array[PackedScene] = []

@export_group("Darstellung")
@export var visual_scale := 1.0
@export var visual_offset := Vector3.ZERO
@export var anim_speed := Vector2(0.2, 1.5)
@export var volume_db := Vector2(-30.0, -6.0)

var _source := ""


## Erzeugt die passende Logik-Instanz (GeneratorPlant oder StoragePlant).
@abstract func create_plant() -> PowerPlant


## Gebäude-Szene, falls die plant.json keine eigene "scene" angibt.
@abstract func _default_building_scene() -> PackedScene


## Füllt den Steckbrief aus dem JSON-Inhalt. Unterklassen ergänzen ihre eigenen Felder.
func load_from_dict(data: Dictionary, p_folder: String, source: String) -> void:
	folder = p_folder
	_source = source
	id = StringName(_value(data, "id", folder.get_file()))
	display_name = _value(data, "display_name", String(id))
	sort_order = int(_value(data, "sort_order", 0))
	build_cost = int(_value(data, "build.cost", 0))
	var area: Array = _value(data, "build.area_usage", [1, 1])
	area_usage = Vector2i(int(area[0]), int(area[1]))
	unit_power_mw = float(_value(data, "power.unit_power_mw", 0.0))
	ramp_per_tick = float(_value(data, "power.ramp_per_tick", 100.0))

	icon = _load_asset(_value(data, "assets.icon", ""))
	model = _load_asset(_value(data, "assets.model", ""))
	animation = StringName(_value(data, "assets.animation", ""))
	var texture_paths: Dictionary = _value(data, "assets.textures", {})
	for key: String in texture_paths:
		var texture := _load_asset(texture_paths[key]) as Texture2D
		if texture:
			textures[key] = texture
	var sound_paths: Dictionary = _value(data, "assets.sounds", {})
	for key: String in sound_paths:
		var sound := _load_asset(sound_paths[key]) as AudioStream
		if sound:
			sounds[key] = sound
	for path: String in _value(data, "assets.effects", []):
		var effect := _load_asset(path) as PackedScene
		if effect:
			effects.append(effect)
	var custom_scene := _load_asset(_value(data, "assets.scene", "")) as PackedScene
	building_scene = custom_scene if custom_scene else _default_building_scene()

	visual_scale = float(_value(data, "visual.scale", 1.0))
	var offset: Array = _value(data, "visual.offset", [0, 0, 0])
	visual_offset = Vector3(offset[0], offset[1], offset[2])
	var speed: Array = _value(data, "visual.anim_speed", [0.2, 1.5])
	anim_speed = Vector2(speed[0], speed[1])
	var volume: Array = _value(data, "visual.volume_db", [-30, -6])
	volume_db = Vector2(volume[0], volume[1])


## Liest ein Feld per Pfad ("power.unit_power_mw"). Fehlt es, gibt es eine Warnung und den Standardwert.
## null in der JSON bedeutet "bewusst leer" und liefert still den Standardwert.
func _value(data: Dictionary, path: String, default: Variant) -> Variant:
	var current: Variant = data
	for key in path.split("."):
		if not (current is Dictionary and current.has(key)):
			push_warning("%s: Feld '%s' fehlt – Standardwert %s wird verwendet." % [_source, path, var_to_str(default)])
			return default
		current = current[key]
	return default if current == null else current


## Lädt eine Datei relativ zum Typ-Ordner. Leer = kein Asset, fehlend = Warnung.
func _load_asset(relative_path: String) -> Resource:
	if relative_path.is_empty():
		return null
	var path := folder.path_join(relative_path)
	if not ResourceLoader.exists(path):
		push_warning("%s: Asset '%s' nicht gefunden – Platzhalter wird verwendet." % [_source, path])
		return null
	return load(path)
