class_name GeneratorPlant
extends PowerPlant
## Erzeuger: folgt dem Sollwert mit Rampe, begrenzt durch Mindestlast und aktuelle Verfügbarkeit.

var _noise := FastNoiseLite.new()
var _tick_index := 0


func setup(p_definition: PlantDefinition, noise_seed: int) -> void:
	super(p_definition, noise_seed)
	_noise.seed = noise_seed + hash(definition.id)
	_noise.frequency = (definition as GeneratorDefinition).noise_frequency


func tick(inputs: SimInputs, _tick_hours: float) -> void:
	var def := definition as GeneratorDefinition
	installed_power_mw = unit_count * def.unit_power_mw

	var availability := availability_modifier
	if def.input_curve:
		availability *= def.input_curve.sample(inputs.get_value(def.input_key))
	if def.variability > 0.0:
		availability *= 1.0 + def.variability * _noise.get_noise_1d(_tick_index)
	available_power_mw = clampf(availability, 0.0, 1.0) * installed_power_mw
	_tick_index += 1

	var target_mw := 0.0
	if enabled:
		target_mw = minf(maxf(setpoint, def.min_load) / 100.0 * installed_power_mw, available_power_mw)
	_ramp_towards(target_mw)
	# Fällt die Verfügbarkeit plötzlich (Sturm, Nacht), sinkt die Leistung sofort.
	actual_power_mw = minf(actual_power_mw, available_power_mw)
	state_changed.emit(self)
