class_name GridCollapseRule
extends RefCounted
## Entscheidet, ob das Netz in einer Runde zusammengebrochen ist: wenn die Leistungsbilanz
## max_red_hours am Stück im roten Bereich war. Wieder gelb oder grün → die Zeit läuft von vorne.
## RoundStats füttert die Regel nach jedem Tick (observe) und setzt sie zum Rundenstart zurück (reset).
## Der Zusammenbruch beendet die Runde nicht, er erscheint nur in der Auswertung.
## Ein anderes Kriterium: Unterklasse anlegen und _is_critical() bzw. observe() überschreiben.

## Wie lange die Bilanz am Stück kritisch sein darf, in simulierten Stunden. 0 = Netz bricht nie zusammen.
var max_red_hours := 1.0

## Zeitpunkt des Zusammenbruchs in Stunden seit Rundenstart, negativ = nicht zusammengebrochen.
var collapse_hour := -1.0
## Wie lange die Bilanz gerade am Stück kritisch ist, in Stunden.
var red_hours := 0.0
## Längste Zeit am Stück kritisch in dieser Runde, in Stunden (für die Auswertung).
var longest_red_hours := 0.0


func _init(max_hours := 1.0) -> void:
	max_red_hours = max_hours


func reset() -> void:
	collapse_hour = -1.0
	red_hours = 0.0
	longest_red_hours = 0.0


func has_collapsed() -> bool:
	return collapse_hour >= 0.0


## Nach jedem Tick: Stufe der Bilanz in diesem Tick, Dauer des Ticks und Zeit seit Rundenstart (nach dem Tick).
func observe(zone: BalanceBands.Zone, tick_hours: float, hours_since_start: float) -> void:
	if not _is_critical(zone):
		red_hours = 0.0
		return
	red_hours += tick_hours
	longest_red_hours = maxf(longest_red_hours, red_hours)
	# Kleine Toleranz, damit z. B. 20 × 0,05 h trotz Rundungsfehler als 1 h zählen.
	if max_red_hours > 0.0 and not has_collapsed() and red_hours >= max_red_hours - 1e-6:
		collapse_hour = hours_since_start


## Zählt diese Stufe für den Zusammenbruch?
func _is_critical(zone: BalanceBands.Zone) -> bool:
	return zone == BalanceBands.Zone.RED
