class_name SimInputs
extends Resource
## Momentaufnahme der Einflussgrößen (Wetter, Tageszeit) für einen Tick.
## Die Anlagen kennen die Quelle nicht – das Wetter-System kommt später.

@export_range(0.0, 1.0, 0.01) var solar_irradiance := 1.0
@export_range(0.0, 40.0, 0.1, "suffix:m/s") var wind_speed := 8.0
@export_range(0.0, 1.0, 0.01) var water_flow := 1.0
@export_range(0.0, 1.0, 0.01) var cooling_water := 1.0
@export_range(0.0, 24.0, 0.1, "suffix:h") var time_of_day_h := 12.0


## Liefert eine Einflussgröße über ihren Namen (z. B. &"wind_speed"), unbekannt = 0.
func get_value(key: StringName) -> float:
	var value: Variant = get(key)
	return value if value is float else 0.0
