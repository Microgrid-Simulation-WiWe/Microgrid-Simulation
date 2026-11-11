class_name WeatherGenerator
extends RefCounted
## Seeded hourly weather generator. Reads its parameters from weather.json.
##
##     var weather := WeatherGenerator.new("res://weather.json")
##     var period := weather.generate(12345, "summer", 7)     # seed, season, number of days
##     for hour in period.hours:
##         print(hour.day, " ", hour.hour, ":00  ", hour.temperature, " degC  ", hour.solar_radiation, " W/m2")
##
## period.hours has 24 entries per day, period.days one entry per day.
## Seasons are "spring" (Mar-May), "summer" (Jun-Aug), "autumn" (Sep-Nov), "winter" (Dec-Feb).
## The seed also picks where in the season the period starts, unless you pass start_offset.
## The same arguments give the same weather in the same Godot version.

const DAYS_IN_MONTH: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const SEASON_START_MONTH := {"spring": 3, "summer": 6, "autumn": 9, "winter": 12}
const MIN_SUN_HEIGHT := 0.035  # below this sine of the sun height, radiation counts as 0

var params: Dictionary

var _rng := RandomNumberGenerator.new()
var _year: int
var _month: int  # 0 = January, as in weather.json
var _day: int
var _prev_wet: bool
var _temp_z: float  # temperature anomaly, carried from day to day
var _wind_z: float  # standard normal wind anomaly, carried from day to day


func _init(json_path: String = "res://weather.json") -> void:
	var text := FileAccess.get_file_as_string(json_path)
	assert(text != "", "Cannot read %s" % json_path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "%s is not valid JSON" % json_path)
	params = parsed
	assert(int(params.format_version) == 3, "Unsupported weather.json format")


## Generates a whole period of hourly weather inside a season.
## year is the year the season starts in, which only matters for leap years.
## start_offset is the number of days after the season's first day; -1 lets the seed pick it.
## A period longer than the season simply runs on into the next season.
func generate(
	seed_value: int, season: String, days: int, year: int = 2026, start_offset: int = -1
) -> Dictionary:
	assert(SEASON_START_MONTH.has(season), "Unknown season: %s" % season)
	assert(days >= 1, "A period needs at least one day")

	var offset := start_offset
	if offset < 0:
		var picker := RandomNumberGenerator.new()
		picker.seed = seed_value
		offset = picker.randi_range(0, maxi(0, _season_length(season, year) - days))

	_set_date(year, SEASON_START_MONTH[season] - 1, 1)
	for i in range(offset):
		_advance_date()
	start(seed_value, _year, _month + 1, _day)

	# One extra day so the last evening can blend towards the next morning.
	var day_list: Array[Dictionary] = []
	for i in range(days + 1):
		day_list.append(next_day())
	var hours := _expand_to_hours(day_list, days)
	day_list.pop_back()
	return {"seed": seed_value, "season": season, "days": day_list, "hours": hours}


## Restarts the day sequence. Pass the seed you want, or params.default_seed.
func start(seed_value: int, year: int, month: int, day: int) -> void:
	_rng.seed = seed_value
	_year = year
	_month = month - 1
	_day = day

	# Start from the long-run state of the first month.
	var rain: Dictionary = params.precipitation
	var p_wet: float = rain.p_dw[_month] / (1.0 - rain.p_ww[_month] + rain.p_dw[_month])
	_prev_wet = _rng.randf() < p_wet
	var temp: Dictionary = params.temperature
	_temp_z = _rng.randfn() * temp.innovation_sigma[_month] / sqrt(1.0 - temp.ar1_phi ** 2)
	_wind_z = _rng.randfn()


## Generates the current day and moves on to the next one.
func next_day() -> Dictionary:
	var m := _month
	var doy := _day_of_year()

	# 1) Rain: Markov chain on wet/dry, then a Gamma amount.
	var rain: Dictionary = params.precipitation
	var wet: bool = _rng.randf() < (rain.p_ww[m] if _prev_wet else rain.p_dw[m])
	var state := "wet" if wet else "dry"
	var precipitation := 0.0
	if wet:
		var amount := _gamma(rain.gamma_shape[m], rain.gamma_scale[m])
		precipitation = maxf(snappedf(amount, 0.1), rain.wet_threshold_mm)

	# 2) Temperature: yearly cycle + wet/dry offset + AR(1) anomaly.
	var temp: Dictionary = params.temperature
	_temp_z = temp.ar1_phi * _temp_z + temp.innovation_sigma[m] * _rng.randfn()
	var tmean: float = _seasonal_temperature(doy) + temp.state_offset[state][m] + _temp_z
	var span_params: Dictionary = temp.range[state]
	var span := _gamma(span_params.gamma_shape[m], span_params.gamma_scale[m])
	var above: float = span_params.frac_above_mean[m]

	# 3) Sunshine: chance of no sun, otherwise a Beta share of the day length.
	var sun: Dictionary = params.sunshine[state]
	var sunshine := 0.0
	if _rng.randf() >= sun.p_zero[m]:
		sunshine = _beta(sun.beta_alpha[m], sun.beta_beta[m])
	var day_length := day_length_hours(doy)

	# 4) Cloud cover follows from the sunshine, so the two always agree.
	var cloud: Dictionary = params.cloud[state]
	var cloud_cover: float = clampf(
		cloud.intercept + cloud.slope * sunshine + cloud.noise_sd * _rng.randfn(), 0.0, 1.0
	)

	# 5) Snow: rain falls as snow on cold days.
	var snow: bool = wet and tmean < params.snow.threshold_tmean_c

	# 6) Wind: shifted Gamma with a persistent anomaly; a gust factor on top.
	var phi: float = params.wind.ar1_phi
	_wind_z = phi * _wind_z + sqrt(1.0 - phi * phi) * _rng.randfn()
	var wind: Dictionary = params.wind[state]
	var wind_speed := _shifted_gamma_from_normal(wind.gamma_shape[m], wind.gamma_scale[m], _wind_z)
	var gust: Dictionary = params.gust[state]
	var gust_noise: float = params.gust.wind_slope * _wind_z + gust.sigma_log[m] * _rng.randfn()
	var gust_factor: float = gust.median_factor[m] * exp(gust_noise)

	var result := {
		"year": _year,
		"month": _month + 1,
		"day": _day,
		"day_of_year": doy,
		"wet": wet,
		"precipitation": precipitation,
		"snow": snow,
		"snowfall": precipitation if snow else 0.0,
		"temperature_mean": tmean,
		"temperature_max": tmean + above * span,
		"temperature_min": tmean - (1.0 - above) * span,
		"sunshine_fraction": sunshine,
		"sunshine_hours": sunshine * day_length,
		"day_length_hours": day_length,
		"cloud_cover": cloud_cover,
		"wind_speed": wind_speed,
		"wind_gust": wind_speed * maxf(params.gust.min_factor, gust_factor),
	}
	_prev_wet = wet
	_advance_date()
	return result


func _season_length(season: String, year: int) -> int:
	_set_date(year, SEASON_START_MONTH[season] - 1, 1)
	var length := 0
	for i in range(3):
		length += _days_in_current_month()
		_day = _days_in_current_month()
		_advance_date()
	return length


func _set_date(year: int, month: int, day: int) -> void:
	_year = year
	_month = month
	_day = day


# Turns daily weather into hours. The daily rain and sunshine totals are kept exactly.
func _expand_to_hours(day_list: Array[Dictionary], days: int) -> Array[Dictionary]:
	var h: Dictionary = params.hourly
	var sky := _ar1_series(h.sky.phi, 24 * days)
	var wind_noise := _ar1_series(h.wind_noise_phi, 24 * days)

	var tmean := PackedFloat64Array()
	var trange := PackedFloat64Array()
	var wind_daily := PackedFloat64Array()
	var cloud_daily := PackedFloat64Array()
	for d in day_list:
		tmean.append(d.temperature_mean)
		trange.append(d.temperature_max - d.temperature_min)
		wind_daily.append(d.wind_speed)
		cloud_daily.append(d.cloud_cover)

	# Wind: blend the daily means, add the daily rhythm and noise, then correct each day's mean.
	var wind_raw := PackedFloat64Array()
	wind_raw.resize(24 * days)
	var wind_factor := PackedFloat64Array()
	for i in range(days):
		var total := 0.0
		for hour in range(24):
			var noise: float = exp(h.wind_noise_sd * wind_noise[24 * i + hour])
			var value: float = (
				_blend(wind_daily, i, hour) * h.wind_shape[day_list[i].month - 1][hour] * noise
			)
			wind_raw[24 * i + hour] = value
			total += value
		wind_factor.append(wind_daily[i] * 24.0 / total)
	wind_factor.append(wind_factor[days - 1])

	var hours: Array[Dictionary] = []
	for i in range(days):
		var day: Dictionary = day_list[i]
		var m: int = day.month - 1
		var doy: int = day.day_of_year
		var day_sky := sky.slice(24 * i, 24 * i + 24)
		var rain := _distribute_rain(day, m, day_sky)
		var sun_above := _sun_hours_available(doy)
		var sun_height := _sun_height(doy)
		var sun := _distribute_sunshine(day, day_sky, sun_above, sun_height)
		var state := "wet" if day.wet else "dry"
		for hour in range(24):
			var sun_share: float = sun[hour] / sun_above[hour] if sun_above[hour] > 0.0 else 0.0
			var cloud: float = _blend(cloud_daily, i, hour)
			if sun_above[hour] > 0.0:
				cloud += params.cloud[state].slope * (sun_share - day.sunshine_fraction)
			hours.append({
				"year": day.year,
				"month": day.month,
				"day": day.day,
				"hour": hour,
				"day_index": i,
				"temperature":
				_blend(tmean, i, hour) + _blend(trange, i, hour) * h.temperature_shape[m][hour],
				"precipitation": rain[hour],
				"snow": day.snow and rain[hour] > 0.0,
				"sunshine_fraction": sun_share,
				"sunshine_hours": sun[hour],
				"solar_radiation":
				_solar_radiation(doy, m, sun_height[hour], sun_share, sun_above[hour]),
				"cloud_cover": clampf(cloud, 0.0, 1.0),
				"wind_speed":
				minf(
					wind_raw[24 * i + hour] * _blend(wind_factor, i, hour),
					wind_daily[i] * h.wind_max_ratio
				),
			})
	return hours


# A standard normal series where each value leans on the one before.
func _ar1_series(phi: float, count: int) -> PackedFloat64Array:
	var series := PackedFloat64Array()
	series.resize(count)
	var value := _rng.randfn()
	var keep := sqrt(1.0 - phi * phi)
	for i in range(count):
		series[i] = value
		value = phi * value + keep * _rng.randfn()
	return series


# Value of a daily series at an hour, moving smoothly from one midday to the next.
func _blend(values: PackedFloat64Array, day: int, hour: int) -> float:
	var t := (hour + 0.5) / 24.0 - 0.5
	var first := day - 1 if t < 0.0 else day
	var weight := t + 1.0 if t < 0.0 else t
	var a := values[maxi(first, 0)]
	var b := values[mini(first + 1, values.size() - 1)]
	return lerpf(a, b, weight)


# Rain falls in the cloudiest hours of the day.
func _distribute_rain(day: Dictionary, m: int, sky: PackedFloat64Array) -> PackedFloat64Array:
	var rain := PackedFloat64Array()
	rain.resize(24)
	if not day.wet:
		return rain
	var r: Dictionary = params.hourly.rain
	var log_hours: float = (
		r.hours_intercept[m] + r.hours_slope * log(day.precipitation) + r.hours_noise_sd * _rng.randfn()
	)
	var count := clampi(roundi(exp(log_hours)), 1, 24)
	var order: Array[int] = []
	for hour in range(24):
		order.append(hour)
	order.sort_custom(func(a: int, b: int) -> bool: return sky[a] > sky[b])
	var weights := PackedFloat64Array()
	var total := 0.0
	for i in range(count):
		weights.append(exp(r.weight_sd * _rng.randfn()))
		total += weights[i]
	for i in range(count):
		rain[order[i]] = day.precipitation * weights[i] / total
	return rain


# Sunshine falls in the clearest hours, favouring a high sun. Returns hours of sun per hour.
func _distribute_sunshine(
	day: Dictionary,
	sky: PackedFloat64Array,
	sun_above: PackedFloat64Array,
	sun_height: PackedFloat64Array
) -> PackedFloat64Array:
	var sun := PackedFloat64Array()
	sun.resize(24)
	var target: float = day.sunshine_hours
	if target <= 0.0:
		return sun
	var s: Dictionary = params.hourly.sky
	var scores := PackedFloat64Array()
	for hour in range(24):
		scores.append(-sky[hour] + s.sun_height_weight * maxf(sun_height[hour], 0.0))

	# Search the cut-off that hands out exactly the day's sunshine hours.
	var low := -30.0
	var high := 30.0
	for i in range(40):
		var cut := (low + high) / 2.0
		var total := 0.0
		for hour in range(24):
			total += sun_above[hour] / (1.0 + exp((cut - scores[hour]) / s.softness))
		if total > target:
			low = cut
		else:
			high = cut
	var cut_off := (low + high) / 2.0
	for hour in range(24):
		sun[hour] = sun_above[hour] / (1.0 + exp((cut_off - scores[hour]) / s.softness))
	return sun


func _solar_noon() -> float:
	return 12.0 + (15.0 - params.hourly.longitude_deg) / 15.0


# Share of each hour with the sun above the horizon.
func _sun_hours_available(doy: int) -> PackedFloat64Array:
	var half_day := day_length_hours(doy) / 2.0
	var sunrise := _solar_noon() - half_day
	var sunset := _solar_noon() + half_day
	var available := PackedFloat64Array()
	for hour in range(24):
		available.append(maxf(0.0, minf(hour + 1.0, sunset) - maxf(float(hour), sunrise)))
	return available


# Sine of the sun height in the middle of each hour.
func _sun_height(doy: int) -> PackedFloat64Array:
	var lat: float = deg_to_rad(params.latitude_deg)
	var delta := 0.409 * sin(TAU * doy / 365.0 - 1.39)
	var height := PackedFloat64Array()
	for hour in range(24):
		var angle := deg_to_rad(15.0 * (hour + 0.5 - _solar_noon()))
		height.append(sin(lat) * sin(delta) + cos(lat) * cos(delta) * cos(angle))
	return height


func _solar_radiation(doy: int, m: int, height: float, sun_share: float, above: float) -> float:
	if height <= MIN_SUN_HEIGHT:
		return 0.0
	var s: Dictionary = params.hourly.solar
	var top: float = s.solar_constant * (1.0 + 0.033 * cos(TAU * doy / 365.0)) * height
	var clear_share: float = (s.a + s.b * sun_share) * exp(-s.c / height)
	return top * clear_share * s.monthly_scale[m] * minf(above, 1.0)


## Astronomical day length; same formula as day_length_hours in build_weather_json.py.
func day_length_hours(doy: int) -> float:
	var lat := deg_to_rad(params.latitude_deg)
	var delta := 0.409 * sin(TAU * doy / 365.0 - 1.39)
	return 24.0 * acos(-tan(lat) * tan(delta)) / PI


func _seasonal_temperature(doy: int) -> float:
	var f: Dictionary = params.temperature.fourier
	var w: float = TAU * (doy - 1) / f.period_days
	var value: float = f.a0
	for k in range(f.cos.size()):
		value += f.cos[k] * cos((k + 1) * w) + f.sin[k] * sin((k + 1) * w)
	return value


func _is_leap_year() -> bool:
	return (_year % 4 == 0 and _year % 100 != 0) or _year % 400 == 0


func _days_in_current_month() -> int:
	return DAYS_IN_MONTH[_month] + (1 if _month == 1 and _is_leap_year() else 0)


func _day_of_year() -> int:
	var doy := _day
	for i in range(_month):
		doy += DAYS_IN_MONTH[i] + (1 if i == 1 and _is_leap_year() else 0)
	return doy


func _advance_date() -> void:
	_day += 1
	if _day > _days_in_current_month():
		_day = 1
		_month += 1
		if _month == 12:
			_month = 0
			_year += 1


# Wilson-Hilferty: turns a standard normal value into a Gamma value, in closed form.
func _shifted_gamma_from_normal(shape: float, scale: float, z: float) -> float:
	var base := maxf(1.0 - 1.0 / (9.0 * shape) + z / (3.0 * sqrt(shape)), 0.0)
	return params.wind.loc + shape * scale * base * base * base


# randf() can return exactly 0, which log() and pow() cannot take.
func _uniform_open() -> float:
	return maxf(_rng.randf(), 1e-12)


# Gamma(shape, 1) by Marsaglia-Tsang.
func _gamma_unit(shape: float) -> float:
	if shape < 1.0:
		return _gamma_unit(shape + 1.0) * pow(_uniform_open(), 1.0 / shape)
	var d := shape - 1.0 / 3.0
	var c := 1.0 / sqrt(9.0 * d)
	while true:
		var x := _rng.randfn()
		var v := 1.0 + c * x
		if v <= 0.0:
			continue
		v = v * v * v
		var u := _uniform_open()
		if u < 1.0 - 0.0331 * x * x * x * x or log(u) < 0.5 * x * x + d * (1.0 - v + log(v)):
			return d * v
	return 0.0  # never reached


func _gamma(shape: float, scale: float) -> float:
	return scale * _gamma_unit(shape)


func _beta(alpha: float, beta: float) -> float:
	var x := _gamma_unit(alpha)
	var y := _gamma_unit(beta)
	return x / (x + y)
