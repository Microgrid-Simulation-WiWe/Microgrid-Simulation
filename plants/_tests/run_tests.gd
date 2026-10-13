extends SceneTree
## Headless-Tests für die Anlagen-Logik. Aufruf (aus dem Projektordner):
##   godot --headless --path . --script res://plants/_tests/run_tests.gd

const FIXTURES_DIR := "res://plants/_tests/fixtures"
const BASE_TYPES: Array[StringName] = [&"solar", &"wind", &"hydro", &"coal", &"gas", &"nuclear", &"battery", &"pumped_hydro"]

var _failures := 0


func _initialize() -> void:
	# Erst im ersten Frame ist der Szenenbaum aktiv (nötig für _ready des EnergyMix).
	_run_all.call_deferred()


func _run_all() -> void:
	_test_registry()
	_test_generators()
	_test_storage()
	_test_energy_mix()
	_test_loading_errors()
	print("ALLE TESTS OK" if _failures == 0 else "%d TEST(S) FEHLGESCHLAGEN" % _failures)
	quit(_failures)


func _test_registry() -> void:
	print("Registry")
	var all := PlantRegistry.get_all()
	var missing := BASE_TYPES.filter(func(id: StringName) -> bool: return PlantRegistry.get_by_id(id) == null)
	_check(missing.is_empty(), "alle Grundtypen gefunden (fehlend: %s)" % [missing])
	var sorted := range(1, all.size()).all(func(i: int) -> bool: return all[i - 1].sort_order <= all[i].sort_order)
	_check(sorted, "nach sort_order sortiert")
	_check(PlantRegistry.get_by_id(&"wind") is GeneratorDefinition, "wind ist ein Generator")
	_check(PlantRegistry.get_by_id(&"pumped_hydro") is StorageDefinition, "pumped_hydro ist ein Speicher")
	_check(PlantRegistry.get_by_id(&"wind").building_scene != null, "Standard-Gebäudeszene gesetzt")


func _test_generators() -> void:
	print("Erzeuger")
	var inputs := SimInputs.new()

	var wind := _make_plant(&"wind")
	wind.setpoint = 100.0
	inputs.wind_speed = 12.0
	_run(wind, inputs, 1)
	_check(wind.actual_power_mw > 1.7 and wind.actual_power_mw <= 2.0, "Wind bei 12 m/s ≈ 2 MW (%.2f)" % wind.actual_power_mw)
	inputs.wind_speed = 30.0
	_run(wind, inputs, 1)
	_check(is_zero_approx(wind.actual_power_mw), "Wind bei 30 m/s → 0 MW (Sturm)")
	wind.free()

	var solar := _make_plant(&"solar")
	solar.setpoint = 100.0
	inputs.solar_irradiance = 0.0
	_run(solar, inputs, 3)
	_check(is_zero_approx(solar.actual_power_mw), "Solar bei Einstrahlung 0 → 0 MW")
	solar.free()

	var nuclear := _make_plant(&"nuclear")
	nuclear.setpoint = 0.0
	inputs = SimInputs.new()
	_run(nuclear, inputs, 60)
	_check(is_equal_approx(nuclear.actual_power_mw, 5.0), "Atom an mit Sollwert 0 → bleibt bei 50 %% (%.2f MW)" % nuclear.actual_power_mw)
	nuclear.setpoint = 100.0
	var ticks := 0
	while not is_equal_approx(nuclear.actual_power_mw, 10.0) and ticks < 1000:
		nuclear.tick(inputs, 1.0)
		ticks += 1
	_check(ticks == 50, "Atom 50 → 100 %% dauert 50 Ticks (%d)" % ticks)
	nuclear.free()

	var gas := _make_plant(&"gas", 0)
	gas.setpoint = 100.0
	_run(gas, inputs, 5)
	_check(is_zero_approx(gas.actual_power_mw), "unit_count 0 → 0 MW")
	gas.unit_count = 1
	_run(gas, inputs, 20)
	_check(is_equal_approx(gas.actual_power_mw, 3.0), "Gas mit Sollwert 100 → 3 MW")
	gas.enabled = false
	_run(gas, inputs, 9)
	_check(gas.actual_power_mw > 0.0, "Gas aus → fährt mit Rampe herunter")
	_run(gas, inputs, 1)
	_check(is_zero_approx(gas.actual_power_mw), "Gas aus → nach 10 Ticks bei 0 MW")
	gas.free()


func _test_storage() -> void:
	print("Speicher")
	var inputs := SimInputs.new()
	var battery := _make_plant(&"battery") as StoragePlant
	battery.setpoint = 100.0
	_run(battery, inputs, 1)
	_check(is_equal_approx(battery.actual_power_mw, 1.9), "Entladen begrenzt durch Ladestand (%.2f MW)" % battery.actual_power_mw)
	_run(battery, inputs, 3)
	_check(is_zero_approx(battery.actual_power_mw) and is_zero_approx(battery.state_of_charge), "Batterie leer → 0 MW")
	battery.setpoint = -100.0
	_run(battery, inputs, 1)
	_check(is_equal_approx(battery.actual_power_mw, -2.0), "Laden mit -2 MW")
	_check(is_equal_approx(battery.state_of_charge, 2.0 * 0.95 / 4.0), "Ladestand mit Wirkungsgrad (%.3f)" % battery.state_of_charge)
	battery.free()


func _test_energy_mix() -> void:
	print("EnergyMix + Gebäude")
	var mix := EnergyMix.new()
	root.add_child(mix)
	_check(mix.get_child_count() == PlantRegistry.get_all().size(), "eine Logik-Instanz pro Typ")
	var building := mix.build(&"wind")
	_check(building is GeneratorBuilding, "build() liefert GeneratorBuilding")
	_check(mix.get_plant(&"wind").unit_count == 1, "build() erhöht unit_count")
	_check(building.get_node("Model").get_child_count() == 1, "Platzhalter-Modell ohne Asset")
	var storage_building := mix.build(&"battery")
	_check(storage_building is StorageBuilding, "build() liefert StorageBuilding")
	mix.get_plant(&"wind").setpoint = 100.0
	mix.tick()
	_check(mix.total_power_mw > 0.0, "tick() summiert die Leistung (%.2f MW)" % mix.total_power_mw)
	building.free()
	storage_building.free()
	mix.free()


func _test_loading_errors() -> void:
	print("Laden (Fixtures, Warnungen/Fehler darüber sind erwartet)")
	PlantRegistry.scan(FIXTURES_DIR)
	var minimal := PlantRegistry.get_by_id(&"minimal") as GeneratorDefinition
	_check(minimal != null and minimal.ramp_per_tick == 100.0 and minimal.input_curve == null, "fehlende Felder → Standardwerte")
	_check(PlantRegistry.get_all().size() == 2, "unbekannter type und doppelte id → übersprungen")
	var missing := PlantRegistry.get_by_id(&"missing_asset")
	_check(missing is StorageDefinition and missing.icon == null, "fehlendes Asset → kein Absturz, icon leer")
	PlantRegistry.scan()


func _make_plant(id: StringName, units := 1) -> PowerPlant:
	var definition := PlantRegistry.get_by_id(id)
	var plant := definition.create_plant()
	plant.setup(definition, 0)
	plant.unit_count = units
	return plant


func _run(plant: PowerPlant, inputs: SimInputs, ticks: int) -> void:
	for i in ticks:
		plant.tick(inputs, 1.0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok      ", description)
	else:
		_failures += 1
		printerr("  FEHLER  ", description)
