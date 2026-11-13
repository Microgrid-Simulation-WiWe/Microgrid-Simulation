class_name ConsumerProfile
extends RefCounted
## Tageskurve eines Verbrauchers (Anteil der Spitze über die Uhrzeit), geladen aus consumers/*.json.

var id := ""
var display_name := ""
var default_peak_kw := 100.0
var base_load_on_inactive_day := false
var winter: Array[Vector2] = []
var summer: Array[Vector2] = []


static func from_dict(data: Dictionary) -> ConsumerProfile:
	var p := ConsumerProfile.new()
	p.id = data.get("id", "")
	p.display_name = data.get("display_name", p.id)
	p.default_peak_kw = data.get("default_peak_kw", 100.0)
	p.base_load_on_inactive_day = data.get("inactive_day", "normal") == "base_load"
	p.winter = _points(data.get("winter", []))
	p.summer = _points(data.get("summer", data.get("winter", [])))
	return p


## Herbst und Winter = Winter-Kurve, Frühling und Sommer = Sommer-Kurve.
static func uses_winter_curve(season: String) -> bool:
	return season == "winter" or season == "autumn"


func get_kw(hour: float, peak_kw: float, winter_curve: bool, active_day := true) -> float:
	var curve := winter if winter_curve else summer
	var h := fposmod(hour, 24.0)
	var level := curve[0].y if (not active_day and base_load_on_inactive_day) else _interpolate(curve, h)
	# Kleine, reproduzierbare Schwankung (Geräte, Pumpen), ca. ±3 %.
	var wobble := 1.0 + 0.03 * sin(h * 17.3) + 0.02 * sin(h * 41.9 + 1.7)
	return peak_kw * level * wobble


static func _points(raw: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for entry in raw:
		result.append(Vector2(entry[0], entry[1]))
	return result


static func _interpolate(points: Array[Vector2], hour: float) -> float:
	for i in points.size() - 1:
		if hour <= points[i + 1].x:
			return lerpf(points[i].y, points[i + 1].y, inverse_lerp(points[i].x, points[i + 1].x, hour))
	return points[points.size() - 1].y
