class_name DemandDisplay
extends Label
## Zeigt den aktuellen Verbrauch (EnergyMix.demand_kw) samt Verbrauchername.

@export var energy_mix: EnergyMix
@export var consumer: ConsumerDemand


func _process(_delta: float) -> void:
	var kw := energy_mix.demand_kw
	var title := "Verbrauch" if consumer == null or consumer.consumer_name.is_empty() else "Verbrauch (%s)" % consumer.consumer_name
	text = "%s: %.2f MW" % [title, kw / 1000.0] if kw >= 1000.0 else "%s: %.0f kW" % [title, kw]
