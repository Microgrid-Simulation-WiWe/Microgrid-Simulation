extends Control
## Zeigt die Netzfrequenz an (oben Mitte, unter der Uhr): Wert in Farbe und Balken von min_hz bis max_hz.

const GREEN_BAND_HZ := 0.2  # Normalbereich im echten Netz: 49,8–50,2 Hz
const YELLOW_BAND_HZ := 1.0
const GREEN := Color("4caf50")
const YELLOW := Color("ffc107")
const RED := Color("f44336")
const BAR_HEIGHT := 10.0

@export var energy_mix: EnergyMix
## Grenzen des Balkens. Außerhalb bricht das Netz zusammen (Spielende kommt später).
@export var min_hz := 48.0
@export var max_hz := 52.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var hz := energy_mix.frequency_hz
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var small_size := font_size - 4
	draw_string(font, Vector2(0, font.get_ascent(font_size)), "%.2f Hz" % hz,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, _color(hz))

	# Balken rot – gelb – grün – gelb – rot, links und rechts beschriftet.
	var label_width := font.get_string_size("%d" % max_hz, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size).x + 6.0
	var bar := Rect2(label_width, font.get_height(font_size) + 6.0, size.x - 2.0 * label_width, BAR_HEIGHT)
	draw_rect(bar, RED)
	draw_rect(_band(bar, YELLOW_BAND_HZ), YELLOW)
	draw_rect(_band(bar, GREEN_BAND_HZ), GREEN)
	var label_y := bar.position.y + (BAR_HEIGHT + font.get_ascent(small_size)) / 2.0 - 1.0
	draw_string(font, Vector2(0, label_y), "%d" % min_hz, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size)
	draw_string(font, Vector2(bar.end.x + 6.0, label_y), "%d" % max_hz, HORIZONTAL_ALIGNMENT_LEFT, -1, small_size)

	# Markierung; außerhalb des Balkens bleibt sie am Rand stehen.
	var x := _x_of(bar, hz)
	draw_line(Vector2(x, bar.position.y - 4.0), Vector2(x, bar.end.y + 4.0), Color.WHITE, 3.0)


func _color(hz: float) -> Color:
	var deviation := absf(hz - EnergyMix.NOMINAL_HZ)
	if deviation <= GREEN_BAND_HZ:
		return GREEN
	if deviation <= YELLOW_BAND_HZ:
		return YELLOW
	return RED


## Bereich ±half_width_hz um 50 Hz als Teil des Balkens.
func _band(bar: Rect2, half_width_hz: float) -> Rect2:
	var left := _x_of(bar, EnergyMix.NOMINAL_HZ - half_width_hz)
	var right := _x_of(bar, EnergyMix.NOMINAL_HZ + half_width_hz)
	return Rect2(left, bar.position.y, right - left, bar.size.y)


func _x_of(bar: Rect2, hz: float) -> float:
	return bar.position.x + inverse_lerp(min_hz, max_hz, clampf(hz, min_hz, max_hz)) * bar.size.x
