class_name ScenarioSelector
extends PanelContainer
## Auswahl des Szenarios oben in der Mitte (nur in der Bauphase sichtbar, siehe GameFlow.build_ui).
## Überträgt die Werte des gewählten Szenarios auf das Level. Nach dem ersten Bau oder der ersten
## Runde steht das Szenario fest, dann ist die Auswahl gesperrt.

@export var energy_mix: EnergyMix
@export var game_flow: GameFlow
@export var clock_display: ClockDisplay
@export var inventory_bar: InventoryBar
@export var placement: PlacementController
@export var weather_display: WeatherDisplay
@export var screen_margin: int = 16
@export var label_text := "Szenario:"
@export var locked_text := "Das Szenario steht nach dem ersten Bau fest."

var _options: OptionButton
var _scenarios: Array[ScenarioDefinition] = []


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	_options = OptionButton.new()
	_options.focus_mode = Control.FOCUS_NONE
	_options.item_selected.connect(_on_item_selected)
	row.add_child(_options)

	_scenarios = ScenarioRegistry.get_all()
	for scenario in _scenarios:
		_options.add_item(scenario.display_name)
		_options.set_item_tooltip(_options.item_count - 1, _describe(scenario))
	if _scenarios.is_empty():
		# Ohne Szenario gelten die Werte aus der Level-Szene.
		_options.add_item("Kein Szenario")
		_options.disabled = true
	else:
		var current := ScenarioRegistry.get_current()
		_options.select(_scenarios.find(current))
		# Erst wenn alle Knoten bereit sind (InventoryBar.refresh() braucht deren _ready).
		_apply.call_deferred(current)

	placement.building_placed.connect(_lock.unbind(1), CONNECT_ONE_SHOT)
	energy_mix.ticked.connect(_lock, CONNECT_ONE_SHOT)

	# Oben in der Mitte verankern.
	reset_size()
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, screen_margin)


## Überträgt die Werte des Szenarios auf das Level.
func _apply(scenario: ScenarioDefinition) -> void:
	game_flow.round_hours = scenario.round_hours
	clock_display.start_hour = scenario.start_hour
	energy_mix.tick_hours = scenario.tick_hours
	energy_mix.ticks_per_second = scenario.get_ticks_per_second()
	energy_mix.random_seed = scenario.random_seed
	for definition in PlantRegistry.get_all():
		var plant := energy_mix.get_plant(definition.id)
		if plant != null:
			plant.power_factor = scenario.get_power_factor(definition.id)
	energy_mix.reset()  # Der Seed wirkt erst ab dem Rundenstart.
	inventory_bar.hidden_plants = scenario.forbidden_plants
	inventory_bar.refresh()
	_options.tooltip_text = _describe(scenario)
	if weather_display != null:
		weather_display.set_scenario(scenario)


func _on_item_selected(index: int) -> void:
	var scenario := _scenarios[index]
	ScenarioRegistry.select(scenario.id)
	_apply(scenario)


func _lock() -> void:
	if _options.disabled:
		return
	_options.disabled = true
	_options.tooltip_text = locked_text + "\n\n" + _options.tooltip_text


## Tooltip-Text: Beschreibung und darunter die Hinweise als Aufzählung.
func _describe(scenario: ScenarioDefinition) -> String:
	var lines := PackedStringArray([scenario.description])
	for line in scenario.info:
		lines.append("• " + line)
	return "\n".join(lines).strip_edges()
