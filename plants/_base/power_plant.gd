@abstract
class_name PowerPlant
extends Node
## Logik eines Anlagentyps, aggregiert über alle gebauten Einheiten.
## Wird nur vom EnergyMix getaktet (kein eigenes _process). Alle Steuerwerte setzt der Spieler.

signal state_changed(plant: PowerPlant)

const READ_ONLY := PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY

@export var definition: PlantDefinition

@export_group("Steuerung")
## Sollwert in % der installierten Leistung. Erzeuger: 0..100, Speicher: -100 (laden) .. +100 (entladen).
@export_range(-100.0, 100.0, 1.0, "suffix:%") var setpoint := 0.0
## Aus = Leistung fährt mit der Rampe auf 0.
@export var enabled := true
## Anzahl gebauter Einheiten (setzt die Bauphase).
@export_range(0, 100, 1, "or_greater") var unit_count := 0
## Wirkung von Ereignissen (z. B. Störung): 1 = normal, 0 = keine Leistung.
@export_range(0.0, 1.0, 0.01) var availability_modifier := 1.0

@export_group("Zustand")
@export_custom(PROPERTY_HINT_NONE, "suffix:MW", READ_ONLY) var installed_power_mw := 0.0
@export_custom(PROPERTY_HINT_NONE, "suffix:MW", READ_ONLY) var available_power_mw := 0.0
## Tatsächliche Leistung: + = Einspeisung, − = Aufnahme (Speicher lädt).
@export_custom(PROPERTY_HINT_NONE, "suffix:MW", READ_ONLY) var actual_power_mw := 0.0


func setup(p_definition: PlantDefinition) -> void:
	definition = p_definition
	name = String(definition.id)


## Berechnet die Leistung für einen Tick.
@abstract func tick(tick_hours: float) -> void


## Fährt die Leistung um höchstens ramp_per_tick %-Punkte der installierten Leistung Richtung Ziel.
func _ramp_towards(target_mw: float) -> void:
	var max_step := definition.ramp_per_tick / 100.0 * installed_power_mw
	actual_power_mw = move_toward(actual_power_mw, target_mw, max_step)
