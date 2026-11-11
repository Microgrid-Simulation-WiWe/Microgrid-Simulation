@tool
extends EditorScript

const JSON_PATH := "res://scenarios/weather.json"
const SEASON_MONTHS := {
	"spring": [3, 4, 5], "summer": [6, 7, 8], "autumn": [9, 10, 11], "winter": [12, 1, 2]
}

var failures := 0


func _run() -> void:
	var weather := WeatherGenerator.new(JSON_PATH)

	var first := weather.generate(12345, "summer", 7)
	var again := weather.generate(12345, "summer", 7)
	var other := weather.generate(99, "summer", 7)
	check(str(first.hours) == str(again.hours), "same seed gives the same weather")
	check(str(first.hours) != str(other.hours), "another seed gives other weather")
	check(first.hours.size() == 7 * 24, "7 days give 168 hours")
	check(weather.generate(1, "winter", 1).hours.size() == 24, "1 day gives 24 hours")

	for season in SEASON_MONTHS:
		var period := weather.generate(7, season, 30)
		var in_season := true
		for hour in period.hours:
			in_season = in_season and SEASON_MONTHS[season].has(hour.month)
		check(in_season, "%s period stays in %s" % [season, season])
		print_summary(period)

	var fixed := weather.generate(5, "autumn", 14, 2026, 10)
	check(fixed.days[0].month == 9 and fixed.days[0].day == 11, "start_offset picks the start day")
	check_totals(fixed)

	print("--- first 24 hours, seed 12345, summer ---")
	for i in range(24):
		var h: Dictionary = first.hours[i]
		print("%02d:00  %5.1f degC  %4.1f mm  %4.0f W/m2  sun %3.1f  wind %4.1f m/s" % [
			h.hour, h.temperature, h.precipitation, h.solar_radiation,
			h.sunshine_fraction, h.wind_speed
		])
	print("RESULT: %s" % ("all checks passed" if failures == 0 else "%d FAILED" % failures))


func check_totals(period: Dictionary) -> void:
	var rain_ok := true
	var sun_ok := true
	var wind_ok := true
	for i in range(period.days.size()):
		var rain := 0.0
		var sun := 0.0
		var wind := 0.0
		for hour in period.hours:
			if hour.day_index == i:
				rain += hour.precipitation
				sun += hour.sunshine_hours
				wind += hour.wind_speed / 24.0
		var day: Dictionary = period.days[i]
		rain_ok = rain_ok and absf(rain - day.precipitation) < 0.001
		sun_ok = sun_ok and absf(sun - day.sunshine_hours) < 0.01
		wind_ok = wind_ok and absf(wind - day.wind_speed) < 0.5 * day.wind_speed
	check(rain_ok, "hourly rain adds up to the daily rain")
	check(sun_ok, "hourly sunshine adds up to the daily sunshine")
	check(wind_ok, "hourly wind stays close to the daily mean")


func print_summary(period: Dictionary) -> void:
	var temp := 0.0
	var rain := 0.0
	var solar := 0.0
	var wind := 0.0
	for hour in period.hours:
		temp += hour.temperature
		rain += hour.precipitation
		solar += hour.solar_radiation
		wind += hour.wind_speed
	var n: float = period.hours.size()
	print("%-7s mean %5.1f degC, %5.1f mm rain, %3.0f W/m2 sun, %3.1f m/s wind" % [
		period.season, temp / n, rain, solar / n, wind / n
	])


func check(ok: bool, label: String) -> void:
	print(("ok      " if ok else "FAILED  ") + label)
	if not ok:
		failures += 1
