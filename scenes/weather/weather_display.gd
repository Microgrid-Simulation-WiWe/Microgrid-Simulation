class_name WeatherDisplay
extends TextureRect
## Kleines Wetterbild oben rechts. Wählt aus 4 Bildern das passende zur aktuellen Simulationsstunde.
## Das Wetter kommt aus dem WeatherGenerator, set_scenario() ruft der ScenarioSelector auf.

@export var energy_mix: EnergyMix
@export var clock_display: ClockDisplay
@export var weather_params_path := "res://scenarios/weather.json"
@export var sunny: Texture2D
@export var cloudy: Texture2D
@export var rainy: Texture2D
@export var night: Texture2D
## Ab dieser Bewölkung (0..1) wird das Wolkenbild gezeigt.
@export_range(0.0, 1.0, 0.05) var cloudy_from := 0.5
## Ab dieser Regenmenge pro Stunde (mm) wird das Regenbild gezeigt. Schnee zählt auch als Regen.
@export_range(0.0, 5.0, 0.05) var rain_from_mm := 0.1

var _generator: WeatherGenerator
var _hours: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _process(_delta: float) -> void:
	if _hours.is_empty():
		return
	var hour: Dictionary = _hours[_hour_index()]
	texture = _pick(hour)
	energy_mix.weather_hour = hour
	energy_mix.wind_speed_ms = hour.wind_speed


## Erzeugt das Wetter der Runde. Szenario-JSON: "weather": { "season": "summer", "seed": 12345 }
## Fehlt ein Eintrag, gilt summer und der Seed des Szenarios.
func set_scenario(scenario: ScenarioDefinition) -> void:
	var config := scenario.weather
	var season: String = config.get("season", "summer")
	if not WeatherGenerator.SEASON_START_MONTH.has(season):
		push_warning("Wetter: Unbekannte Jahreszeit '%s', es gilt summer." % season)
		season = "summer"
	var seed_value := int(config.get("seed", scenario.random_seed))
	var start_offset := int(config.get("start_offset", -1))
	# Die Runde startet zur Startuhrzeit und kann in den nächsten Tag reichen.
	var days := ceili((scenario.start_hour + scenario.round_hours) / 24.0)
	if _generator == null:
		_generator = WeatherGenerator.new(weather_params_path)
	_hours = _generator.generate(seed_value, season, days, 2026, start_offset).hours

## Wetterwerte der aktuellen Stunde, leer wenn noch kein Wetter erzeugt wurde.
func get_current_hour() -> Dictionary:
	if _hours.is_empty():
		return {}
	return _hours[_hour_index()]

## Stunde 0 des ersten Tages = 00:00 Uhr.
func _hour_index() -> int:
	var elapsed := clock_display.start_hour + energy_mix.tick_count * energy_mix.tick_hours
	return clampi(floori(elapsed + 0.0001), 0, _hours.size() - 1)


## Reihenfolge: Regen/Schnee, dann Nacht, dann Wolken, sonst Sonne.
func _pick(hour: Dictionary) -> Texture2D:
	if hour.precipitation >= rain_from_mm or hour.snow:
		return rainy
	if hour.solar_radiation <= 0.0:
		return night
	if hour.cloud_cover >= cloudy_from:
		return cloudy
	return sunny
