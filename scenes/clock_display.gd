extends Label
## Zeigt die Simulationsuhrzeit an (oben Mitte). Start 12:00 Uhr, weiter pro Tick um tick_hours.

const START_HOUR := 12.0

@export var energy_mix: EnergyMix


func _process(_delta: float) -> void:
	var minutes := roundi((START_HOUR + energy_mix.tick_count * energy_mix.tick_hours) * 60.0)
	minutes = posmod(minutes, 24 * 60)
	text = "%02d:%02d Uhr" % [floori(minutes / 60.0), minutes % 60]
