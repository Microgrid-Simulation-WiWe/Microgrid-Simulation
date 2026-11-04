extends SceneTree
## Headless-Tests für die Anlagen-Logik. Aufruf (aus dem Projektordner):
##   godot --headless --path . --script res://plants/_tests/run_tests.gd

const FIXTURES_DIR := "res://plants/_tests/fixtures"
const BASE_TYPES: Array[StringName] = [&"solar", &"wind", &"hydro", &"coal", &"gas", &"nuclear", &"battery"]

var _failures := 0


func _initialize() -> void:
	# Erst im ersten Frame ist der Szenenbaum aktiv (nötig für _ready des EnergyMix).
	_run_all.call_deferred()


func _run_all() -> void:
	_test_registry()
	_test_generators()
	_test_storage()
	_test_energy_mix()
	_test_frequency()
	_test_energy_balance()
	_test_pause_and_reset()
	_test_round_stats()
	_test_random()
	_test_loading_errors()
	_test_grid_occupancy()
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
	_check(PlantRegistry.get_by_id(&"battery") is StorageDefinition, "battery ist ein Speicher")
	_check(PlantRegistry.get_by_id(&"wind").building_scene != null, "Standard-Gebäudeszene gesetzt")
	var categories := PlantRegistry.get_categories()
	var categories_sorted := range(1, categories.size()).all(
		func(i: int) -> bool: return categories[i - 1].sort_order <= categories[i].sort_order)
	_check(not categories.is_empty() and categories_sorted, "Kategorien geladen und sortiert (%d)" % categories.size())
	_check(PlantRegistry.get_by_id(&"wind").category == &"renewable", "wind ist erneuerbar")
	_check(PlantRegistry.get_in_category(&"conventional").has(PlantRegistry.get_by_id(&"coal")), "coal liegt in conventional")
	_check(PlantRegistry.get_uncategorized().is_empty(), "jeder Grundtyp hat eine gültige Kategorie")


func _test_generators() -> void:
	print("Erzeuger")
	var wind := _make_plant(&"wind")
	wind.setpoint = 100.0
	_run(wind, 1)
	_check(is_equal_approx(wind.actual_power_mw, 2.0), "Wind mit Sollwert 100 → 2 MW (%.2f)" % wind.actual_power_mw)
	wind.setpoint = 50.0
	_run(wind, 1)
	_check(is_equal_approx(wind.actual_power_mw, 1.0), "Wind mit Sollwert 50 → 1 MW (%.2f)" % wind.actual_power_mw)
	wind.availability_modifier = 0.0
	_run(wind, 1)
	_check(is_zero_approx(wind.actual_power_mw), "Wind mit Störfaktor 0 → 0 MW")
	wind.free()

	var noisy := _make_plant(&"wind") as GeneratorPlant
	noisy.setpoint = 50.0
	noisy.noise_level = 0.2
	var low := INF
	var high := -INF
	for i in 200:
		noisy.tick(1.0)
		low = minf(low, noisy.actual_power_mw)
		high = maxf(high, noisy.actual_power_mw)
	_check(low >= 0.6 - 0.001 and high <= 1.4 + 0.001 and high - low > 0.1,
		"Zufall ±20 %% um 1 MW (%.2f … %.2f MW)" % [low, high])
	noisy.free()

	var nuclear := _make_plant(&"nuclear")
	nuclear.setpoint = 0.0
	_run(nuclear, 60)
	_check(is_equal_approx(nuclear.actual_power_mw, 5.0), "Atom an mit Sollwert 0 → bleibt bei 50 %% (%.2f MW)" % nuclear.actual_power_mw)
	nuclear.setpoint = 100.0
	var ticks := 0
	while not is_equal_approx(nuclear.actual_power_mw, 10.0) and ticks < 1000:
		nuclear.tick(1.0)
		ticks += 1
	_check(ticks == 50, "Atom 50 → 100 %% dauert 50 Ticks (%d)" % ticks)
	nuclear.free()

	var gas := _make_plant(&"gas", 0)
	gas.setpoint = 100.0
	_run(gas, 5)
	_check(is_zero_approx(gas.actual_power_mw), "unit_count 0 → 0 MW")
	gas.unit_count = 1
	_run(gas, 20)
	_check(is_equal_approx(gas.actual_power_mw, 3.0), "Gas mit Sollwert 100 → 3 MW")
	gas.enabled = false
	_run(gas, 9)
	_check(gas.actual_power_mw > 0.0, "Gas aus → fährt mit Rampe herunter")
	_run(gas, 1)
	_check(is_zero_approx(gas.actual_power_mw), "Gas aus → nach 10 Ticks bei 0 MW")
	gas.free()


func _test_storage() -> void:
	print("Speicher")
	var battery := _make_plant(&"battery") as StoragePlant
	battery.setpoint = 100.0
	_run(battery, 1)
	_check(is_equal_approx(battery.actual_power_mw, 1.9), "Entladen begrenzt durch Ladestand (%.2f MW)" % battery.actual_power_mw)
	_run(battery, 3)
	_check(is_zero_approx(battery.actual_power_mw) and is_zero_approx(battery.state_of_charge), "Batterie leer → 0 MW")
	battery.setpoint = -100.0
	_run(battery, 1)
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
	mix.demolish(storage_building)
	_check(mix.get_plant(&"battery").unit_count == 0, "demolish() senkt unit_count")
	mix.get_plant(&"wind").setpoint = 100.0
	mix.tick()
	_check(mix.total_power_mw > 0.0, "tick() summiert die Leistung (%.2f MW)" % mix.total_power_mw)
	building.free()
	storage_building.free()
	mix.free()


func _test_frequency() -> void:
	print("Netzfrequenz")
	var mix := EnergyMix.new()
	root.add_child(mix)
	mix.demand_kw = 2000.0
	var wind := mix.get_plant(&"wind") as GeneratorPlant
	wind.unit_count = 1
	wind.noise_level = 0.0
	wind.setpoint = 100.0
	mix.tick()
	_check(is_equal_approx(mix.frequency_hz, 50.0), "Erzeugung = Verbrauch → 50 Hz (%.2f)" % mix.frequency_hz)
	wind.setpoint = 50.0
	mix.tick()
	_check(mix.frequency_hz < 50.0 and mix.frequency_hz > 47.5, "zu wenig Erzeugung → fällt träge (%.2f Hz)" % mix.frequency_hz)
	for i in 50:
		mix.tick()
	_check(is_equal_approx(mix.frequency_hz, 47.5), "50 %% Unterdeckung → 47,5 Hz (%.2f)" % mix.frequency_hz)
	mix.demand_kw = 0.0
	for i in 50:
		mix.tick()
	_check(is_equal_approx(mix.frequency_hz, 50.0), "demand_kw 0 → zurück auf 50 Hz (%.2f)" % mix.frequency_hz)
	mix.free()


func _test_energy_balance() -> void:
	print("Energiebilanz")
	var mix := EnergyMix.new()
	root.add_child(mix)
	mix.tick_hours = 10.0 / 60.0
	mix.demand_kw = 2000.0
	var wind := mix.get_plant(&"wind") as GeneratorPlant
	wind.unit_count = 1
	wind.noise_level = 0.0
	wind.setpoint = 100.0
	mix.tick()
	_check(is_equal_approx(mix.energy_balance_kwh, 0.0), "Erzeugung = Verbrauch → 0 kWh (%.2f)" % mix.energy_balance_kwh)
	wind.setpoint = 50.0
	mix.tick()
	_check(is_equal_approx(mix.energy_balance_kwh, -1000.0 / 6.0), "1 MW Unterdeckung, 10 min → −166,67 kWh (%.2f)" % mix.energy_balance_kwh)
	mix.demand_kw = 0.0
	mix.tick()
	_check(is_equal_approx(mix.energy_balance_kwh, 0.0), "demand_kw 0 → Erzeugung zählt als Plus (%.2f)" % mix.energy_balance_kwh)
	mix.free()


func _test_pause_and_reset() -> void:
	print("Anhalten + Zurücksetzen")
	var mix := EnergyMix.new()
	root.add_child(mix)
	mix.running = false
	mix._process(5.0)
	_check(mix.tick_count == 0, "running aus → kein Tick")
	mix.running = true
	mix._process(2.0)
	_check(mix.tick_count == 2, "running an → Ticks laufen (%d)" % mix.tick_count)

	var wind := mix.get_plant(&"wind")
	wind.unit_count = 1
	wind.setpoint = 100.0
	wind.availability_modifier = 0.5
	var battery := mix.get_plant(&"battery") as StoragePlant
	battery.unit_count = 1
	battery.setpoint = 100.0
	for i in 3:
		mix.tick()
	var soc_before := battery.state_of_charge
	mix.reset()
	_check(mix.tick_count == 0 and is_zero_approx(mix.energy_balance_kwh) and is_zero_approx(mix.total_power_mw)
		and is_equal_approx(mix.frequency_hz, 50.0), "reset() → Uhr, Bilanz, Leistung und Frequenz auf Start")
	_check(is_zero_approx(wind.actual_power_mw) and wind.availability_modifier == 1.0, "reset() → Anlage bei 0 MW, keine Störung")
	_check(soc_before < 0.5 and is_equal_approx(battery.state_of_charge, 0.5),
		"reset() → Ladestand zurück auf initial_soc (vorher %.2f)" % soc_before)
	_check(wind.unit_count == 1 and wind.setpoint == 100.0, "reset() → unit_count und Sollwert bleiben")
	mix.free()


func _test_round_stats() -> void:
	print("Rundenauswertung")
	var nuclear_def := PlantRegistry.get_by_id(&"nuclear") as GeneratorDefinition
	var coal_def := PlantRegistry.get_by_id(&"coal") as GeneratorDefinition
	_check(nuclear_def.nuclear_waste_mg_per_kwh > 0.0 and coal_def.co2_g_per_kwh > 0.0 and coal_def.cost_ct_per_kwh > 0.0,
		"impact-Felder aus plant.json geladen")

	var mix := EnergyMix.new()
	root.add_child(mix)
	mix.tick_hours = 10.0 / 60.0
	mix.demand_kw = 2000.0
	var stats := RoundStats.new()
	stats.energy_mix = mix
	root.add_child(stats)
	var wind := mix.get_plant(&"wind") as GeneratorPlant
	var wind_def := wind.definition as GeneratorDefinition
	wind.unit_count = 1
	wind.noise_level = 0.0
	wind.setpoint = 100.0
	for i in 6:
		mix.tick()
	_check(is_equal_approx(stats.energy_kwh[wind], 2000.0), "2 MW für 1 h → 2000 kWh (%.1f)" % stats.energy_kwh[wind])
	_check(is_equal_approx(stats.total_co2_g(), 2000.0 * wind_def.co2_g_per_kwh), "CO₂ = kWh × co2_g_per_kwh")
	_check(is_equal_approx(stats.total_cost_eur(), 20.0 * wind_def.cost_ct_per_kwh), "Kosten = kWh × ct / 100")
	_check(is_equal_approx(stats.average_cost_ct_per_kwh(), wind_def.cost_ct_per_kwh), "nur Wind → Durchschnitt = ct/kWh von Wind")
	_check(is_zero_approx(stats.total_nuclear_waste_mg()), "ohne Atom kein Atommüll")
	_check(stats.stability() == 1.0 and is_zero_approx(stats.shortfall_kwh), "Erzeugung = Verbrauch → immer im grünen Bereich")
	wind.setpoint = 50.0
	for i in 6:
		mix.tick()
	_check(is_equal_approx(stats.stability(), 0.5), "halbe Runde zu wenig → 50 %% stabil (%.2f)" % stats.stability())
	_check(is_equal_approx(stats.shortfall_kwh, 1000.0), "1 MW Unterdeckung für 1 h → 1000 kWh (%.1f)" % stats.shortfall_kwh)
	mix.reset()
	mix.tick()
	_check(stats.ticks == 1 and is_equal_approx(stats.energy_kwh[wind], 1000.0 / 6.0), "neue Runde → zählt von vorne")
	stats.free()
	mix.free()


func _test_random() -> void:
	print("Zufall")
	var mix := _make_noisy_mix(1)
	var first := _record_wind(mix, 20)
	mix.reset()
	_check(_record_wind(mix, 20) == first, "reset() → Runde hat dieselben Zufallswerte")

	var same := _make_noisy_mix(1)
	_check(_record_wind(same, 20) == first, "gleicher Seed → gleiche Werte")
	same.free()

	var other := _make_noisy_mix(2)
	_check(_record_wind(other, 20) != first, "anderer Seed → andere Werte")
	other.free()

	var with_coal := _make_noisy_mix(1)
	var coal := with_coal.get_plant(&"coal")
	coal.unit_count = 1
	coal.setpoint = 100.0
	_check(_record_wind(with_coal, 20) == first, "Zufallswerte hängen nicht davon ab, welche Anlagen laufen")
	with_coal.free()

	_check(mix.create_rng(EnergyMix.SEED_OFFSET_GENERATOR_NOISE).randi() == mix.create_rng(EnergyMix.SEED_OFFSET_GENERATOR_NOISE).randi()
		and mix.create_rng(EnergyMix.SEED_OFFSET_GENERATOR_NOISE).randi() != mix.create_rng(EnergyMix.SEED_OFFSET_BUILD_POSITION).randi(),
		"fester Wert je Funktion → eigene Zahlenfolge")
	mix.free()


## EnergyMix mit einem verrauschten Windrad bei 50 %.
func _make_noisy_mix(random_seed: int) -> EnergyMix:
	var mix := EnergyMix.new()
	mix.random_seed = random_seed
	root.add_child(mix)
	var wind := mix.get_plant(&"wind") as GeneratorPlant
	wind.unit_count = 1
	wind.noise_level = 0.5
	wind.setpoint = 50.0
	return mix


func _record_wind(mix: EnergyMix, ticks: int) -> Array[float]:
	var values: Array[float] = []
	for i in ticks:
		mix.tick()
		values.append(mix.get_plant(&"wind").actual_power_mw)
	return values


func _test_loading_errors() -> void:
	print("Laden (Fixtures, Warnungen/Fehler darüber sind erwartet)")
	PlantRegistry.scan(FIXTURES_DIR)
	var minimal := PlantRegistry.get_by_id(&"minimal") as GeneratorDefinition
	_check(minimal != null and minimal.ramp_per_tick == 100.0, "fehlende Felder → Standardwerte")
	_check(PlantRegistry.get_all().size() == 2, "unbekannter type und doppelte id → übersprungen")
	_check(PlantRegistry.get_by_id(&"hidden") == null, "Punkt-Ordner (.hidden) → übersprungen")
	var missing := PlantRegistry.get_by_id(&"missing_asset")
	_check(missing is StorageDefinition and missing.icon == null, "fehlendes Asset → kein Absturz, icon leer")
	_check(PlantRegistry.get_categories().is_empty() and PlantRegistry.get_uncategorized().size() == 2,
		"ohne categories.json → keine Kategorien, alle Typen ohne Kategorie")
	PlantRegistry.scan()


func _test_grid_occupancy() -> void:
	print("Rasterbelegung")
	var grid := GridOccupancy.new()
	var owner := RefCounted.new()
	grid.occupy(Rect2i(0, 0, 2, 2), owner)
	_check(not grid.can_place(Rect2i(1, 1, 2, 2)), "überlappende Fläche → belegt")
	_check(grid.can_place(Rect2i(2, 0, 2, 2)), "angrenzende Fläche → frei")
	_check(grid.get_occupant(Vector2i(1, 1)) == owner, "Feld kennt seinen Beleger")
	_check(grid.can_place(Rect2i(1, 1, 2, 2), owner), "eigene Fläche zählt beim Verschieben als frei")
	_check(not grid.can_place(Rect2i(1, 1, 2, 2), RefCounted.new()), "fremde Fläche bleibt beim Verschieben belegt")
	grid.release(owner)
	_check(grid.can_place(Rect2i(0, 0, 2, 2)) and grid.get_occupant(Vector2i(1, 1)) == null, "release() → wieder frei")


func _make_plant(id: StringName, units := 1) -> PowerPlant:
	return _create_plant(PlantRegistry.get_by_id(id), units)


func _create_plant(definition: PlantDefinition, units := 1) -> PowerPlant:
	var plant := definition.create_plant()
	plant.setup(definition)
	plant.unit_count = units
	plant.rng.seed = 0 # fester Seed, damit die Tests bei jedem Lauf gleich sind
	return plant


func _run(plant: PowerPlant, ticks: int) -> void:
	for i in ticks:
		plant.tick(1.0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok      ", description)
	else:
		_failures += 1
		printerr("  FEHLER  ", description)
