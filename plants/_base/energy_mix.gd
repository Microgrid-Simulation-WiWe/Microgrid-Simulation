class_name EnergyMix
extends Node
## Erzeugt beim Start je Anlagentyp eine Logik-Instanz (als Kind-Node) und taktet alle Anlagen.

## Nach jedem Simulationsschritt, wenn alle Werte aktuell sind.
signal ticked

const NOMINAL_HZ := 50.0
## Feste Werte je Zufallsfunktion. Sie werden auf random_seed addiert, damit jede Funktion ihre eigene Zahlenfolge hat.
## Neue Zufallsfunktion → neuer Wert hier.
const SEED_OFFSET_GENERATOR_NOISE := 1000
const SEED_OFFSET_BUILD_POSITION := 2000

## Simulierte Dauer eines Ticks. Wird nur für die Speicher-Energie gebraucht.
@export_range(0.01, 24.0, 0.01, "suffix:h") var tick_hours := 10.0 / 60.0
## Ticks pro Echtzeit-Sekunde. 0 = nur manuell über tick().
@export_range(0.0, 60.0, 0.1) var ticks_per_second := 1.0
## Aus = Simulation angehalten (Bauphase). tick() von Hand geht trotzdem.
@export var running := true

## Summe aller Anlagen: + = Einspeisung, − = Aufnahme.
@export_custom(PROPERTY_HINT_NONE, "suffix:MW", PowerPlant.READ_ONLY) var total_power_mw := 0.0

@export_group("Verbrauch")
## Platzhalter-Verbrauch, bis es echte Verbraucher gibt. 0 = kein Ungleichgewicht.
@export_range(0.0, 1000.0, 1.0, "or_greater", "suffix:kW") var demand_kw := 20.0
## Aufsummierte Energiebilanz: + = mehr erzeugt als verbraucht, − = Unterdeckung. Ziel: nahe 0.
@export_custom(PROPERTY_HINT_NONE, "suffix:kWh", PowerPlant.READ_ONLY) var energy_balance_kwh := 0.0

@export_group("Netzfrequenz")
## Wird nur noch mitgeführt, für den Spielablauf zählt energy_balance_kwh.
## Abweichung bei 100 % Ungleichgewicht (Erzeugung doppelt so groß wie Verbrauch bzw. 0).
@export_range(0.0, 20.0, 0.1, "suffix:Hz") var hz_per_imbalance := 5.0
## Trägheit: Anteil, um den sich die Frequenz pro Tick dem Zielwert nähert. 1 = sofort.
@export_range(0.01, 1.0, 0.01) var frequency_response := 0.3
@export_custom(PROPERTY_HINT_NONE, "suffix:Hz", PowerPlant.READ_ONLY) var frequency_hz := NOMINAL_HZ

@export_group("Zufall")
## Zentraler Seed für alle Zufallswerte im Spiel. Gleicher Seed → auf jedem Rechner dieselben Ereignisse.
## Wirkt ab dem nächsten Rundenstart (reset).
@export var random_seed := 1

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
	_reset_random()

	print("Plants:")
	print("\n".join(_plants))


func _process(delta: float) -> void:
	if not running or ticks_per_second <= 0.0:
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
	var balance_kw := total_power_mw * 1000.0 - demand_kw
	energy_balance_kwh += balance_kw * tick_hours
	# Zu viel Erzeugung → Frequenz steigt, zu wenig → sie fällt. Träge wie eine Schwungmasse.
	var imbalance := balance_kw / demand_kw if demand_kw > 0.0 else 0.0
	frequency_hz = lerpf(frequency_hz, NOMINAL_HZ + hz_per_imbalance * imbalance, frequency_response)
	ticked.emit()


## Zurück auf den Rundenstart: Uhr, Bilanz, Frequenz, Anlagenzustand und Zufall.
## Gebaute Einheiten (unit_count) und Sollwerte bleiben.
func reset() -> void:
	tick_count = 0
	_time_since_tick = 0.0
	total_power_mw = 0.0
	energy_balance_kwh = 0.0
	frequency_hz = NOMINAL_HZ
	for plant in _plants:
		plant.reset()
	_reset_random()


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


## Bauphase: Gegenstück zu build(), zählt die Einheit des Gebäudes wieder ab.
## Entfernen aus der Welt (queue_free()) übernimmt der Aufrufer.
func demolish(building: PlantBuilding) -> void:
	building.plant.unit_count = maxi(building.plant.unit_count - 1, 0)


## Neuer Zufallsgenerator für eine Zufallsfunktion: zentraler Seed plus ihr fester Wert (SEED_OFFSET_*).
func create_rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + offset
	return rng


## Jede Zufallsfunktion der Simulation beginnt ihre Zahlenfolge von vorne.
func _reset_random() -> void:
	var noise_rng := create_rng(SEED_OFFSET_GENERATOR_NOISE)
	for plant in _plants:
		plant.rng = noise_rng
