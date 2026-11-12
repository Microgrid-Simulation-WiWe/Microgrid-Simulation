class_name RoundStats
extends Node
## Zählt während einer Runde mit, was die Auswertung danach anzeigt.
## Beginnt mit dem ersten Tick jeder Runde von vorne.

@export var energy_mix: EnergyMix

## Entscheidet, ob das Netz zusammengebrochen ist. Die Grenze setzt der ScenarioSelector aus dem Szenario.
var collapse_rule := GridCollapseRule.new()
var ticks := 0
var ticks_in_band := 0
## Zu wenig bzw. zu viel erzeugte Energie, über die Runde aufsummiert.
var shortfall_kwh := 0.0
var surplus_kwh := 0.0
var min_hz := INF
var max_hz := -INF
## Erzeugte Energie je Erzeuger, in der Reihenfolge des Baumenüs.
var energy_kwh: Dictionary[GeneratorPlant, float] = {}


func _ready() -> void:
	energy_mix.ticked.connect(_on_ticked)
	reset()


func reset() -> void:
	ticks = 0
	ticks_in_band = 0
	shortfall_kwh = 0.0
	surplus_kwh = 0.0
	min_hz = INF
	max_hz = -INF
	collapse_rule.reset()
	energy_kwh.clear()
	for definition in PlantRegistry.get_all():
		var plant := energy_mix.get_plant(definition.id) as GeneratorPlant
		if plant != null:
			energy_kwh[plant] = 0.0


## Simulierte Dauer der Runde bis jetzt.
func hours() -> float:
	return ticks * energy_mix.tick_hours


## Anteil der Ticks im grünen Bereich, 0..1.
func stability() -> float:
	return float(ticks_in_band) / ticks if ticks > 0 else 0.0


## Ist das Netz in dieser Runde zusammengebrochen? Zeitpunkt: collapse_rule.collapse_hour.
func has_collapsed() -> bool:
	return collapse_rule.has_collapsed()


func co2_g(plant: GeneratorPlant) -> float:
	return energy_kwh[plant] * (plant.definition as GeneratorDefinition).co2_g_per_kwh


func cost_eur(plant: GeneratorPlant) -> float:
	return energy_kwh[plant] * (plant.definition as GeneratorDefinition).cost_ct_per_kwh / 100.0


func nuclear_waste_mg(plant: GeneratorPlant) -> float:
	return energy_kwh[plant] * (plant.definition as GeneratorDefinition).nuclear_waste_mg_per_kwh


func total_co2_g() -> float:
	return _sum(co2_g)


func total_cost_eur() -> float:
	return _sum(cost_eur)


func total_nuclear_waste_mg() -> float:
	return _sum(nuclear_waste_mg)


func total_energy_kwh() -> float:
	return _sum(func(plant: GeneratorPlant) -> float: return energy_kwh[plant])


## Durchschnittliche Kosten je erzeugter kWh über alle Erzeuger.
func average_cost_ct_per_kwh() -> float:
	var energy := total_energy_kwh()
	return total_cost_eur() * 100.0 / energy if energy > 0.0 else 0.0


func _on_ticked() -> void:
	if energy_mix.tick_count == 1:
		reset()
	ticks += 1
	var balance_kw := energy_mix.get_balance_kw()
	var zone := energy_mix.get_balance_zone()
	if zone == BalanceBands.Zone.GREEN:
		ticks_in_band += 1
	collapse_rule.observe(zone, energy_mix.tick_hours, hours())
	if balance_kw < 0.0:
		shortfall_kwh -= balance_kw * energy_mix.tick_hours
	else:
		surplus_kwh += balance_kw * energy_mix.tick_hours
	min_hz = minf(min_hz, energy_mix.frequency_hz)
	max_hz = maxf(max_hz, energy_mix.frequency_hz)
	for plant in energy_kwh:
		energy_kwh[plant] += plant.actual_power_mw * 1000.0 * energy_mix.tick_hours


## Summe über alle Erzeuger.
func _sum(per_plant: Callable) -> float:
	var sum := 0.0
	for plant in energy_kwh:
		sum += per_plant.call(plant)
	return sum
