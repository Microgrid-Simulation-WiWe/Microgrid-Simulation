extends Control
## Zeigt die Leistungsbilanz an (oben Mitte, unter der Uhr): Erzeugung − Verbrauch in Farbe
## und als Balken von −demand_kw bis +demand_kw.

const GREEN := Color("4caf50")
const YELLOW := Color("ffc107")
const RED := Color("f44336")
const BAR_HEIGHT := 10.0

@export var energy_mix: EnergyMix
## Farbstufen als Anteil des Verbrauchs (Platzhalter, Balancing kommt später).
@export_range(0.0, 1.0, 0.01) var green_band := 0.1
@export_range(0.0, 1.0, 0.01) var yellow_band := 0.3


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var demand_mw := energy_mix.demand_kw / 1000.0
	var balance_mw := energy_mix.total_power_mw - demand_mw
	# Anteil am Verbrauch, −1 = nichts erzeugt. Ohne Verbrauch gibt es kein Ungleichgewicht.
	var imbalance := balance_mw / demand_mw if demand_mw > 0.0 else 0.0
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var small_size := font_size - 4
	draw_string(font, Vector2(0, font.get_ascent(font_size)), _format(balance_mw),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, _color(imbalance))

	# Balken rot – gelb – grün – gelb – rot, links und rechts mit ±Verbrauch beschriftet.
	var demand_label := "%d MW" % roundi(demand_mw) if demand_mw >= 1.0 else _format_unsigned(demand_mw)
	var min_label := "−" + demand_label
	var max_label := "+" + demand_label
	var label_width := font.get_string_size(max_label, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x + 6.0
	var bar := Rect2(label_width, font.get_height(font_size) + 6.0, size.x - 2.0 * label_width, BAR_HEIGHT)
	draw_rect(bar, RED)
	draw_rect(_band(bar, yellow_band), YELLOW)
	draw_rect(_band(bar, green_band), GREEN)
	var label_y := bar.position.y + (BAR_HEIGHT + font.get_ascent(small_size)) / 2.0 - 1.0
	draw_string(font, Vector2(0, label_y), min_label, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size)
	draw_string(font, Vector2(bar.end.x + 6.0, label_y), max_label, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size)

	# Markierung; außerhalb des Balkens bleibt sie am Rand stehen.
	var x := _x_of(bar, imbalance)
	draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y + 4.0), Color.WHITE, 3.0)


## Mit Vorzeichen (außer bei 0), unter 1 MW in kW, darüber in MW.
func _format(mw: float) -> String:
	if absf(mw) < 0.0005:
		return "0 kW"
	return ("−" if mw < 0.0 else "+") + _format_unsigned(absf(mw))


func _format_unsigned(mw: float) -> String:
	if mw < 1.0:
		return "%.0f kW" % (mw * 1000.0)
	return "%.2f MW" % mw


func _color(imbalance: float) -> Color:
	var deviation := absf(imbalance)
	if deviation <= green_band:
		return GREEN
	if deviation <= yellow_band:
		return YELLOW
	return RED


## Bereich ±half_width um 0 als Teil des Balkens.
func _band(bar: Rect2, half_width: float) -> Rect2:
	var left := _x_of(bar, -half_width)
	var right := _x_of(bar, half_width)
	return Rect2(left, bar.position.y, right - left, bar.size.y)


func _x_of(bar: Rect2, imbalance: float) -> float:
	return bar.position.x + inverse_lerp(-1.0, 1.0, clampf(imbalance, -1.0, 1.0)) * bar.size.x
