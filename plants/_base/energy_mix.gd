class_name EnergyMix
extends Node
## Erzeugt beim Start je Anlagentyp eine Logik-Instanz (als Kind-Node) und taktet alle Anlagen.

## Simulierte Dauer eines Ticks. Wird nur für die Speicher-Energie gebraucht.
@export_range(0.01, 24.0, 0.01, "suffix:h") var tick_hours := 10.0 / 60.0
## Ticks pro Echtzeit-Sekunde. 0 = nur manuell über tick().
@export_range(0.0, 60.0, 0.1) var ticks_per_second := 1.0

## Summe aller Anlagen: + = Einspeisung, − = Aufnahme.
@export_custom(PROPERTY_HINT_NONE, "suffix:MW", PowerPlant.READ_ONLY) var total_power_mw := 0.0

## Anzahl der bisher ausgeführten Ticks.
var tick_count := 0

var _plants: Array[PowerPlant] = []
var _time_since_tick := 0.0


func _ready() -> void:
	for definition in PlantRegistry.get_all():
		var plant := definition.create_plant()
		plant.setup(definition)
		add_child(plant)
		_plants.append(plant)
		
	print("Plants:")
	print("\n".join(_plants))


func _process(delta: float) -> void:
	if ticks_per_second <= 0.0:
		return
	_time_since_tick += delta
	while _time_since_tick >= 1.0 / ticks_per_second:
		_time_since_tick -= 1.0 / ticks_per_second
		tick()


## Ein Simulationsschritt für alle Anlagen.
func tick() -> void:
	tick_count += 1
	total_power_mw = 0.0
	for plant in _plants:
		plant.tick(tick_hours)
		total_power_mw += plant.actual_power_mw


func get_plant(id: StringName) -> PowerPlant:
	for plant in _plants:
		if plant.definition.id == id:
			return plant
	return null


## Bauphase: zählt eine Einheit des Typs dazu und liefert das passende Gebäude.
## Positionieren und add_child() übernimmt der Aufrufer.
func build(id: StringName) -> PlantBuilding:
	var plant := get_plant(id)
	if plant == null:
		push_error("EnergyMix: Unbekannter Anlagentyp '%s'." % id)
		return null
	plant.unit_count += 1
	var building := plant.definition.building_scene.instantiate() as PlantBuilding
	building.setup(plant.definition, plant)
	return building
