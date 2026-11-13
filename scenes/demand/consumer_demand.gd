class_name ConsumerDemand
extends Node
## Setzt den Verbrauch (EnergyMix.demand_kw) nach dem Verbraucher des Szenarios.
## Im Szenario: "consumer": { "profile": "school", "peak_kw": 800 }. peak_kw ist optional.

@export var energy_mix: EnergyMix
@export var clock_display: ClockDisplay
## Gilt, wenn das Szenario keinen Verbraucher nennt.
@export var default_profile := "school"
## Aus = Wochenende/Ferien (je nach Verbraucher nur Grundlast).
@export var active_day := true

## Für die Anzeige.
var consumer_name := ""


func _process(_delta: float) -> void:
	var scenario := ScenarioRegistry.get_current()
	var settings: Dictionary = scenario.consumer if scenario != null else {}
	var profile := ConsumerRegistry.get_by_id(settings.get("profile", default_profile))
	if profile == null:
		return
	consumer_name = profile.display_name
	var season: String = scenario.weather.get("season", "summer") if scenario != null else "summer"
	var peak: float = settings.get("peak_kw", profile.default_peak_kw)
	var hour := clock_display.start_hour + energy_mix.tick_count * energy_mix.tick_hours
	energy_mix.demand_kw = profile.get_kw(hour, peak, ConsumerProfile.uses_winter_curve(season), active_day)
