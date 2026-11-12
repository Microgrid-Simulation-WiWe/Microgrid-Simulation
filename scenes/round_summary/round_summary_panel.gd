class_name RoundSummaryPanel
extends CenteredPanel
## Auswertung nach jeder Runde (Bildschirmmitte): Netzstabilität, CO₂, Atommüll und Kosten, dazu je Erzeuger eine Zeile.
## Erscheint, wenn die Runde endet oder abgebrochen wird. Verschwindet mit „Weiter“ oder beim nächsten Rundenstart.
## Die erste Zeile „Netz“ sagt immer, wie es dem Netz ging (Ampelfarbe, siehe _add_grid_row und GridCollapseRule).

@export var game_flow: GameFlow
@export var round_stats: RoundStats


func _ready() -> void:
	super()
	game_flow.round_finished.connect(_on_round_finished)
	round_stats.energy_mix.ticked.connect(hide)


func _on_round_finished(completed: bool) -> void:
	# Ohne Tick gab es keine Runde, round_stats hätte noch die Zahlen der letzten.
	if round_stats.energy_mix.tick_count == 0:
		return
	clear()
	add_title("Auswertung der Runde")
	# Rundenzeit steht immer da, bei einem Abbruch mit der erreichten Zeit.
	var duration := "%.1f von %.0f h" % [round_stats.hours(), game_flow.round_hours]
	add_text(("Abgebrochen nach " if not completed else "Runde beendet nach ") + duration)

	var summary := _make_grid(2)
	_add_grid_row(summary)
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

	add_buttons(["Weiter"])[0].pressed.connect(hide)
	popup()


func _make_grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 24)
	_content.add_child(grid)
	return grid


## Zeile „Netz“ in Ampelfarbe: grün = nie im roten Bereich, gelb = zeitweise rot, aber nicht zusammengebrochen
## (mit der längsten roten Phase), rot = zusammengebrochen (mit Zeitpunkt).
func _add_grid_row(grid: GridContainer) -> void:
	var rule := round_stats.collapse_rule
	var limit_minutes := rule.max_red_hours * 60.0
	var longest_minutes := rule.longest_red_hours * 60.0
	var text := "stabil, nie im roten Bereich"
	var zone := BalanceBands.Zone.GREEN
	if rule.has_collapsed():
		text = "zusammengebrochen nach %.1f h (%.0f min am Stück im roten Bereich)" % [rule.collapse_hour, limit_minutes]
		zone = BalanceBands.Zone.RED
	elif longest_minutes > 0.0 and limit_minutes > 0.0:
		text = "nicht zusammengebrochen, bis zu %.0f von %.0f min am Stück im roten Bereich" % [longest_minutes, limit_minutes]
		zone = BalanceBands.Zone.YELLOW
	elif longest_minutes > 0.0:
		text = "bis zu %.0f min am Stück im roten Bereich (Zusammenbruch im Szenario aus)" % longest_minutes
		zone = BalanceBands.Zone.YELLOW
	var cells := _add_row(grid, ["Netz", text])
	cells[1].add_theme_color_override("font_color", BalanceBands.color_of(zone))


## Erste Spalte links, Zahlen rechtsbündig. Liefert die Labels der Zeile, z. B. zum Einfärben.
func _add_row(grid: GridContainer, cells: Array) -> Array[Label]:
	var labels: Array[Label] = []
	for i in cells.size():
		var label := Label.new()
		label.text = cells[i]
		if i > 0 and grid.columns > 2:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(label)
		labels.append(label)
	return labels


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
