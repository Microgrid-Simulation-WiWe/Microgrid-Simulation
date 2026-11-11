class_name WeatherDataDisplay
extends Label
## Zeigt die Wetterwerte der aktuellen Simulationsstunde als Text (rechts unter dem Wetterbild).

@export var weather_display: WeatherDisplay


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _process(_delta: float) -> void:
	var hour := weather_display.get_current_hour()
	if hour.is_empty():
		text = ""
		return
	text = "%02d:00   %.1f °C\nRegen %.1f mm\nSonne %.0f W/m²\nSonnenschein %.1f\nWind %.1f m/s" % [
		hour.hour, hour.temperature, hour.precipitation, hour.solar_radiation,
		hour.sunshine_fraction, hour.wind_speed
	]
