@abstract
class_name PlantDefinition
extends Resource
## Steckbrief eines Anlagentyps. Wird von PlantRegistry aus der plant.json im Typ-Ordner erzeugt.
## Feldbeschreibung: res://plants/_base/plant_schema.md

@export var id: StringName
@export var display_name: String
@export var sort_order: int
## id einer Kategorie aus res://plants/categories.json (Reiter in der Inventarleiste).
@export var category: StringName
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
## Drehung in Grad (x, y, z).
@export var visual_rotation := Vector3.ZERO
@export var anim_speed := Vector2(0.2, 1.5)
@export var volume_db := Vector2(-30.0, -6.0)
@export var anim_driver: StringName = &"load"
@export var wind_speed_range := Vector2(1.0, 8.0)
## Mitte der Modell-Grundfläche nach scale und rotation. Wird aus dem Modell berechnet;
## PlantBuilding schiebt das Modell um diesen Wert zurück, damit es mittig auf seiner Fläche steht.
var model_center := Vector3.ZERO

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
	category = StringName(_value(data, "category", ""))
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
	var rotation: Array = _value(data, "visual.rotation", [0, 0, 0])
	visual_rotation = Vector3(rotation[0], rotation[1], rotation[2])
	var speed: Array = _value(data, "visual.anim_speed", [0.2, 1.5])
	anim_speed = Vector2(speed[0], speed[1])
	anim_driver = StringName(_value(data, "visual.anim_driver", "load"))
	var wind_range: Array = _value(data, "visual.wind_speed_range", [1.0, 8.0])
	wind_speed_range = Vector2(wind_range[0], wind_range[1])
	var volume: Array = _value(data, "visual.volume_db", [-30, -6])
	volume_db = Vector2(volume[0], volume[1])

	if model:
		_fit_area_to_model()


## Mit Modell ergibt sich die belegte Fläche aus seiner Grundfläche nach scale und rotation,
## aufgerundet auf ganze Rasterfelder (1 Feld = 1 Welteinheit). build.area_usage gilt dann nicht.
func _fit_area_to_model() -> void:
	var root := model.instantiate()
	var basis := Basis.from_euler(visual_rotation * PI / 180.0).scaled(Vector3.ONE * visual_scale)
	var footprint := _mesh_bounds(root, Transform3D(basis))
	root.free()
	if footprint.size == Vector3.ZERO:
		return
	# Kleine Toleranz, damit z. B. 4.0001 nicht zu 5 Feldern wird.
	area_usage = Vector2i(maxi(1, ceili(footprint.size.x - 0.01)), maxi(1, ceili(footprint.size.z - 0.01)))
	var center := footprint.get_center()
	model_center = Vector3(center.x, 0.0, center.z)


## Hülle aller Meshes unter root, nach der Darstellungs-Transform visual (scale, rotation).
## Jedes Mesh wird einzeln gedreht, das ergibt bei Drehung eine knappere Hülle als das Ganze zu drehen.
func _mesh_bounds(root: Node, visual: Transform3D) -> AABB:
	var bounds := AABB()
	for mesh_instance: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var to_parent := Transform3D()
		var node: Node = mesh_instance
		while node != null:
			if node is Node3D:
				to_parent = (node as Node3D).transform * to_parent
			node = node.get_parent()
		var mesh_bounds := visual * to_parent * mesh_instance.get_aabb()
		bounds = mesh_bounds if bounds.size == Vector3.ZERO else bounds.merge(mesh_bounds)
	return bounds


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
