extends Control
## Zeigt die Leistungsbilanz an (oben Mitte, unter der Uhr): Erzeugung − Verbrauch in Farbe
## und als Balken von −demand_kw bis +demand_kw. Die Farbstufen kommen aus EnergyMix.balance_bands.

const BAR_HEIGHT := 10.0

@export var energy_mix: EnergyMix


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bands := energy_mix.balance_bands
	var demand_mw := energy_mix.demand_kw / 1000.0
	var balance_mw := energy_mix.get_balance_kw() / 1000.0
	var imbalance := BalanceBands.imbalance(energy_mix.get_balance_kw(), energy_mix.demand_kw)
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var small_size := font_size - 4
	draw_string(font, Vector2(0, font.get_ascent(font_size)), _format(balance_mw),
		HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, BalanceBands.color_of(energy_mix.get_balance_zone()))

	# Balken rot – gelb – grün – gelb – rot, links und rechts mit ±Verbrauch beschriftet.
	var demand_label := "%d MW" % roundi(demand_mw) if demand_mw >= 1.0 else _format_unsigned(demand_mw)
	var min_label := "−" + demand_label
	var max_label := "+" + demand_label
	var label_width := font.get_string_size(max_label, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x + 6.0
	var bar := Rect2(label_width, font.get_height(font_size) + 6.0, size.x - 2.0 * label_width, BAR_HEIGHT)
	draw_rect(bar, BalanceBands.color_of(BalanceBands.Zone.RED))
	draw_rect(_band(bar, bands.yellow_band), BalanceBands.color_of(BalanceBands.Zone.YELLOW))
	draw_rect(_band(bar, bands.green_band), BalanceBands.color_of(BalanceBands.Zone.GREEN))
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


## Bereich ±half_width um 0 als Teil des Balkens.
func _band(bar: Rect2, half_width: float) -> Rect2:
	var left := _x_of(bar, -half_width)
	var right := _x_of(bar, half_width)
	return Rect2(left, bar.position.y, right - left, bar.size.y)


func _x_of(bar: Rect2, imbalance: float) -> float:
	return bar.position.x + inverse_lerp(-1.0, 1.0, clampf(imbalance, -1.0, 1.0)) * bar.size.x
