class_name BalanceBands
extends Resource
## Farbstufen der Leistungsbilanz (grün / gelb / rot). Einzige Quelle dafür, was „im roten Bereich“ heißt:
## Leistungsbilanz-Anzeige, Rundenauswertung und Netzzusammenbruch fragen alle hier nach.
## Eine Instanz hängt am EnergyMix (EnergyMix.balance_bands).

enum Zone { GREEN, YELLOW, RED }

const COLORS: Dictionary[Zone, Color] = {
	Zone.GREEN: Color("4caf50"),
	Zone.YELLOW: Color("ffc107"),
	Zone.RED: Color("f44336"),
}

## Bis zu dieser Abweichung (Anteil des Verbrauchs) ist die Bilanz grün (Platzhalter, Balancing kommt später).
@export_range(0.0, 1.0, 0.01) var green_band := 0.1
## Bis zu dieser Abweichung gelb, darüber rot.
@export_range(0.0, 1.0, 0.01) var yellow_band := 0.3


## Abweichung als Anteil des Verbrauchs, −1 = nichts erzeugt. Ohne Verbrauch gibt es kein Ungleichgewicht.
static func imbalance(balance_kw: float, demand_kw: float) -> float:
	return balance_kw / demand_kw if demand_kw > 0.0 else 0.0


static func color_of(zone: Zone) -> Color:
	return COLORS[zone]


## Stufe zu einer Abweichung (Anteil des Verbrauchs, siehe imbalance()).
func zone_of(deviation: float) -> Zone:
	var amount := absf(deviation)
	if amount <= green_band:
		return Zone.GREEN
	if amount <= yellow_band:
		return Zone.YELLOW
	return Zone.RED
