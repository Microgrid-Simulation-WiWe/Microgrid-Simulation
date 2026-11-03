extends SceneTree
## Headless-Tests für die Szenarien. Aufruf (aus dem Projektordner):
##   godot --headless --path . --script res://scenarios/_tests/run_tests.gd

const FIXTURES_DIR := "res://scenarios/_tests/fixtures"

var _failures := 0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	_test_example()
	_test_selection()
	_test_loading()
	print("ALLE TESTS OK" if _failures == 0 else "%d TEST(S) FEHLGESCHLAGEN" % _failures)
	quit(_failures)


func _test_example() -> void:
	print("Beispielszenario")
	var ravensburg := ScenarioRegistry.get_by_id(&"ravensburg")
	_check(ravensburg != null, "ravensburg gefunden")
	if ravensburg == null:
		return
	_check(ravensburg.display_name == "Ravensburg", "Name Ravensburg")
	_check(ravensburg.round_hours == 24.0 and ravensburg.start_hour == 12.0, "24-h-Runde ab 12:00 Uhr")
	_check(is_equal_approx(ravensburg.tick_hours, 0.05) and ravensburg.ticks_per_second == 1.0 and ravensburg.random_seed == 1,
		"Tick 0,05 h, 1 Tick/s, Seed 1 (wie bisher in level.tscn)")
	var all_allowed := PlantRegistry.get_all().all(
		func(definition: PlantDefinition) -> bool: return ravensburg.is_plant_allowed(definition.id))
	_check(all_allowed and ravensburg.power_factors.values().all(func(factor: float) -> bool: return factor == 1.0),
		"alle Anlagentypen erlaubt, Faktor 1")
	_check(ravensburg.grass != null and ravensburg.background == null, "Gras-Mesh geladen, kein Hintergrund")


func _test_selection() -> void:
	print("Auswahl")
	ScenarioRegistry.scan(FIXTURES_DIR)
	var minimal := ScenarioRegistry.get_by_id(&"minimal")
	var forbid := ScenarioRegistry.get_by_id(&"forbid")
	var sorted: Array[ScenarioDefinition] = [minimal, forbid]
	_check(ScenarioRegistry.get_all() == sorted, "nach sort_order sortiert")
	_check(ScenarioRegistry.get_current() == minimal, "ohne Auswahl → erstes Szenario")
	ScenarioRegistry.select(&"forbid")
	_check(ScenarioRegistry.get_current() == forbid, "select() wechselt")
	ScenarioRegistry.select(&"unknown")
	_check(ScenarioRegistry.get_current() == forbid, "unbekannte id → Auswahl bleibt (Fehler darüber erwartet)")
	ScenarioRegistry.scan()
	_check(ScenarioRegistry.get_current() == ScenarioRegistry.get_by_id(&"ravensburg"), "scan() hebt die Auswahl auf")


func _test_loading() -> void:
	print("Laden (Fixtures, Warnungen/Fehler darüber sind erwartet)")
	ScenarioRegistry.scan(FIXTURES_DIR)
	_check(ScenarioRegistry.get_all().size() == 2, "kein JSON-Objekt und doppelte id → übersprungen")
	_check(ScenarioRegistry.get_by_id(&"hidden") == null, "Punkt-Datei (.hidden.json) → übersprungen")

	var minimal := ScenarioRegistry.get_by_id(&"minimal")
	_check(minimal != null and minimal.display_name == "minimal" and minimal.round_hours == 24.0 and minimal.random_seed == 1,
		"fehlende Felder → id aus dem Dateinamen und Standardwerte")

	var forbid := ScenarioRegistry.get_by_id(&"forbid")
	_check(forbid.round_hours == 48.0 and forbid.start_hour == 6.5 and forbid.tick_hours == 0.25
		and forbid.ticks_per_second == 2.0 and forbid.random_seed == 7, "Simulationswerte gelesen")
	_check(forbid.info == PackedStringArray(["wenig Wasser"]), "Hinweise gelesen")
	_check(not forbid.is_plant_allowed(&"nuclear"), "allowed false → verboten")
	_check(is_equal_approx(forbid.get_power_factor(&"hydro"), 0.5), "power_factor 0.5 gelesen")
	_check(forbid.is_plant_allowed(&"wind") and forbid.get_power_factor(&"wind") == 1.0, "allowed/power_factor null → erlaubt, Faktor 1")
	_check(forbid.is_plant_allowed(&"solar") and forbid.get_power_factor(&"solar") == 1.0, "nicht gelisteter Typ → erlaubt, Faktor 1")
	_check(forbid.forbidden_plants.has(&"unknown_type"), "unbekannter Typ → Warnung, kein Absturz")
	_check(forbid.build_area == Vector2i(20, 30) and forbid.ground_color == Color.RED and forbid.weather == {"sun": 0.8},
		"Baufläche, Bodenfarbe und Wetter gelesen")
	_check(forbid.grass == null and forbid.background == null, "fehlendes Asset → kein Absturz, leer")
	ScenarioRegistry.scan()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok      ", description)
	else:
		_failures += 1
		printerr("  FEHLER  ", description)
