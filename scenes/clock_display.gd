class_name ClockDisplay
extends Label
## Zeigt die Simulationsuhrzeit an (oben Mitte). Start bei start_hour, weiter pro Tick um tick_hours.

@export var energy_mix: EnergyMix
## Uhrzeit beim Rundenstart. Setzt das gewählte Szenario.
@export_range(0.0, 24.0, 0.25, "suffix:h") var start_hour := 12.0


func _process(_delta: float) -> void:
	var minutes := roundi((start_hour + energy_mix.tick_count * energy_mix.tick_hours) * 60.0)
	minutes = posmod(minutes, 24 * 60)
	text = "%02d:%02d Uhr" % [floori(minutes / 60.0), minutes % 60]
