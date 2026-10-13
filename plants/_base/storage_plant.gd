class_name StoragePlant
extends PowerPlant
## Speicher: positiver Sollwert entlädt (speist ein), negativer lädt.
## Begrenzt durch Ladestand und Wirkungsgrad – das ist Physik, keine automatische Regelung.

@export_custom(PROPERTY_HINT_RANGE, "0,1,0.001", READ_ONLY) var state_of_charge := 0.0


func setup(p_definition: PlantDefinition, noise_seed: int) -> void:
	super(p_definition, noise_seed)
	state_of_charge = (definition as StorageDefinition).initial_soc


func tick(_inputs: SimInputs, tick_hours: float) -> void:
	var def := definition as StorageDefinition
	installed_power_mw = unit_count * def.unit_power_mw
	var capacity_mwh := unit_count * def.unit_capacity_mwh

	var max_discharge_mw := 0.0
	var max_charge_mw := 0.0
	if capacity_mwh > 0.0 and tick_hours > 0.0:
		max_discharge_mw = minf(installed_power_mw, state_of_charge * capacity_mwh * def.discharge_efficiency / tick_hours)
		max_charge_mw = minf(installed_power_mw, (1.0 - state_of_charge) * capacity_mwh / (def.charge_efficiency * tick_hours))
	max_discharge_mw *= availability_modifier
	max_charge_mw *= availability_modifier
	available_power_mw = max_discharge_mw

	var target_mw := setpoint / 100.0 * installed_power_mw if enabled else 0.0
	_ramp_towards(target_mw)
	actual_power_mw = clampf(actual_power_mw, -max_charge_mw, max_discharge_mw)

	if capacity_mwh > 0.0:
		if actual_power_mw > 0.0:
			state_of_charge -= actual_power_mw * tick_hours / (def.discharge_efficiency * capacity_mwh)
		else:
			state_of_charge -= actual_power_mw * tick_hours * def.charge_efficiency / capacity_mwh
		state_of_charge = clampf(state_of_charge, 0.0, 1.0)
	state_changed.emit(self)
