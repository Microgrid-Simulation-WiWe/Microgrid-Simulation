extends Label
## Zeigt die aktuell erzeugte Gesamtleistung an (oben rechts).

@export var energy_mix: EnergyMix


func _process(_delta: float) -> void:
	var mw := energy_mix.total_power_mw
	if absf(mw) < 0.1:
		text = "Erzeugung: %.3f kW" % (mw * 1000.0)
	else:
		text = "Erzeugung: %.3f MW" % mw
