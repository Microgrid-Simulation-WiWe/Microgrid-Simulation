class_name GeneratorDefinition
extends PlantDefinition
## Steckbrief eines Erzeugers (Wind, Solar, Wasser, Kohle, Gas, Atom …).

@export_group("Dynamik")
@export_range(0.0, 100.0, 1.0, "suffix:%") var min_load := 0.0

@export_group("Einfluss")
## Name der Einflussgröße in SimInputs, leer = immer voll verfügbar.
@export var input_key: StringName
## Kennlinie: Einflussgröße (x) → Verfügbarkeit 0..1 (y).
@export var input_curve: Curve

@export_group("Zufall")
@export_range(0.0, 1.0, 0.01) var variability := 0.0
@export var noise_frequency := 0.05


func create_plant() -> PowerPlant:
	return GeneratorPlant.new()


func _default_building_scene() -> PackedScene:
	return load("res://plants/_base/generator_building_base.tscn")


func load_from_dict(data: Dictionary, p_folder: String, source: String) -> void:
	super(data, p_folder, source)
	min_load = float(_value(data, "power.min_load", 0.0))
	input_key = StringName(_value(data, "input.key", ""))
	if not input_key.is_empty() and not input_key in SimInputs.new():
		push_warning("%s: Unbekannte Einflussgröße '%s' – wird ignoriert." % [_source, input_key])
		input_key = &""
	if not input_key.is_empty():
		input_curve = _curve_from_points(_value(data, "input.curve", []))
	variability = float(_value(data, "variability.amount", 0.0))
	noise_frequency = float(_value(data, "variability.frequency", 0.05))


## Baut aus Stützpunkten [[x, y], …] eine Godot-Curve mit linearen Abschnitten.
static func _curve_from_points(points: Array) -> Curve:
	if points.is_empty():
		return null
	var curve := Curve.new()
	curve.max_domain = points[-1][0]
	curve.min_domain = points[0][0]
	for point: Array in points:
		curve.add_point(Vector2(point[0], point[1]), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return curve
