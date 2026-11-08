class_name RoundSummaryPanel
extends PanelContainer
## Auswertung nach jeder Runde (Bildschirmmitte): Netzstabilität, CO₂, Atommüll und Kosten, dazu je Erzeuger eine Zeile.
## Erscheint, wenn die Runde endet oder abgebrochen wird. Verschwindet mit „Weiter“ oder beim nächsten Rundenstart.

@export var game_flow: GameFlow
@export var round_stats: RoundStats
@export var title_font_size := 24
## Innenabstand zum Rand der Box.
@export var padding := 16

var _content: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)
	game_flow.round_finished.connect(_on_round_finished)
	round_stats.energy_mix.ticked.connect(hide)
	hide()


func _on_round_finished(completed: bool) -> void:
	# Ohne Tick gab es keine Runde, round_stats hätte noch die Zahlen der letzten.
	if round_stats.energy_mix.tick_count == 0:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "Auswertung der Runde"
	title.add_theme_font_size_override("font_size", title_font_size)
	_content.add_child(title)
	if not completed:
		var aborted := Label.new()
		aborted.text = "Abgebrochen nach %.1f von %.0f h" % [round_stats.hours(), game_flow.round_hours]
		_content.add_child(aborted)

	var summary := _make_grid(2)
	_add_row(summary, ["Netzstabilität", "%d %% der Zeit im grünen Bereich" % roundi(round_stats.stability() * 100.0)])
	_add_row(summary, ["Unterdeckung", _format_energy(round_stats.shortfall_kwh)])
	_add_row(summary, ["Überschuss", _format_energy(round_stats.surplus_kwh)])
	_add_row(summary, ["Netzfrequenz", "%.2f – %.2f Hz" % [round_stats.min_hz, round_stats.max_hz]])
	_add_row(summary, ["CO₂", _format_mass(round_stats.total_co2_g())])
	var waste_mg := round_stats.total_nuclear_waste_mg()
	if waste_mg > 0.0:
		_add_row(summary, ["Atommüll", _format_mass(waste_mg / 1000.0)])
	_add_row(summary, ["Kosten", _format_money(round_stats.total_cost_eur())])
	_add_row(summary, ["Kosten pro kWh", "%.1f ct/kWh im Durchschnitt" % round_stats.average_cost_ct_per_kwh()])

	var producers := round_stats.energy_kwh.keys().filter(
		func(plant: GeneratorPlant) -> bool: return round_stats.energy_kwh[plant] > 0.0)
	if not producers.is_empty():
		_content.add_child(HSeparator.new())
		var table := _make_grid(5)
		_add_row(table, ["Anlage", "Energie", "CO₂", "Kosten", "ct/kWh"])
		for plant: GeneratorPlant in producers:
			_add_row(table, [plant.definition.display_name, _format_energy(round_stats.energy_kwh[plant]),
				_format_mass(round_stats.co2_g(plant)), _format_money(round_stats.cost_eur(plant)),
				"%.0f" % (plant.definition as GeneratorDefinition).cost_ct_per_kwh])

	var button := Button.new()
	button.text = "Weiter"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(hide)
	_content.add_child(button)

	show()
	# Erst im nächsten Frame kennt der Container seine neue Mindestgröße.
	set_anchors_and_offsets_preset.call_deferred(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _make_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 24)
	_content.add_child(grid)
	return grid


## Erste Spalte links, Zahlen rechtsbündig.
func _add_row(grid: GridContainer, cells: Array) -> void:
	for i in cells.size():
		var label := Label.new()
		label.text = cells[i]
		if i > 0 and grid.columns > 2:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(label)


func _format_energy(kwh: float) -> String:
	if kwh < 1000.0:
		return "%.0f kWh" % kwh
	return "%.1f MWh" % (kwh / 1000.0)


func _format_mass(grams: float) -> String:
	if grams < 1.0:
		return "%.0f mg" % (grams * 1000.0)
	if grams < 1000.0:
		return "%.0f g" % grams
	if grams < 1000000.0:
		return "%.1f kg" % (grams / 1000.0)
	return "%.1f t" % (grams / 1000000.0)


func _format_money(eur: float) -> String:
	if eur < 100.0:
		return "%.2f €" % eur
	return "%.0f €" % eur
