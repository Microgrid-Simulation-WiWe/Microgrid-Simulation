class_name GeneratorPlant
extends PowerPlant
## Erzeuger: folgt dem Sollwert mit Rampe, begrenzt durch Mindestlast und aktuelle Verfügbarkeit.

@export_group("Zufall")
## Zufallsschwankung der Leistung als Anteil der installierten Leistung (0.1 = ±10 %). 0 = aus.
@export_range(0.0, 1.0, 0.01) var noise_level := 0.0


func tick(_tick_hours: float) -> void:
	var def := definition as GeneratorDefinition
	installed_power_mw = unit_count * def.unit_power_mw
	available_power_mw = clampf(availability_modifier, 0.0, 1.0) * installed_power_mw

	var target_mw := 0.0
	if enabled:
		target_mw = minf(maxf(setpoint, def.min_load) / 100.0 * installed_power_mw, available_power_mw)
	_ramp_towards(target_mw)
	# Zufallswert addieren, nur solange die Anlage Leistung liefert.
	if actual_power_mw > 0.0:
		print(noise_level)
		actual_power_mw += 0.1 * randf_range(-1.0, 1.0) * noise_level * installed_power_mw
	# Die Verfügbarkeit bleibt die Obergrenze. Fällt sie plötzlich (Störung), sinkt die Leistung sofort.
	actual_power_mw = clampf(actual_power_mw, 0.0, available_power_mw)
	state_changed.emit(self)
