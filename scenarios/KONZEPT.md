# Konzept: Szenarien

Stand: 02.11.2026, erste Umsetzung in `res://scenarios/`. Die Feldreferenz steht in [`_base/scenario_schema.md`](_base/scenario_schema.md).

## Ziel

Kanban-Karte „Szenarien im BackEnd anlegen“. Ein Szenario legt fest, unter welchen Bedingungen gespielt wird:
- Rundenlänge, Tickspeed, Startuhrzeit, Seed
- erlaubte Erzeuger und ihre Leistung
- Baufläche, Landschaft, Hintergrund, Wetter
- Name, Beschreibung und Hinweise für den Spieler

Der Spieler wählt das Szenario zu Beginn oben in der Mitte aus. Konkrete Szenarien (Schule, Krankenhaus, Bauernhof, Regenwald, Ravensburg 2100) gibt es noch nicht. `ravensburg.json` ist ein Beispiel mit den Werten des bisherigen Spiels.

## Festgelegte Entscheidungen

- **Eine JSON-Datei pro Szenario**, flach in `res://scenarios/`. Ein neues Szenario braucht keinen Code.
- **`ScenarioRegistry` ist eine statische Klasse** wie die `PlantRegistry`. So bleibt `project.godot` unverändert.
- **Wechsel nur vor dem ersten Bau.** Nach dem ersten gebauten Gebäude oder dem ersten Tick ist das Dropdown gesperrt. Das gilt auch, wenn wieder alles abgerissen wird. Ein anderes Szenario gibt es dann nur über einen Neustart.
- **Kein Neuladen der Szene.** Vor dem ersten Bau gibt es nichts zurückzusetzen, deshalb werden die Werte direkt übernommen.
- **Die Level-Knoten kennen keine Szenarien.** Der `ScenarioSelector` überträgt die Werte auf `GameFlow`, `EnergyMix`, `ClockDisplay` und `InventoryBar`.

## Klassen

```
ravensburg.json ──► ScenarioRegistry (statisch: get_all(), get_by_id(), get_current(), select(), scan())
					  │ liest alle res://scenarios/*.json, prüft, sortiert
					  ▼
					ScenarioDefinition (Resource)  ◄── ScenarioSelector (scenes/scenario/, Dropdown)
					  load_from_dict(),                  überträgt die Werte auf GameFlow, EnergyMix,
					  is_plant_allowed(),                ClockDisplay, InventoryBar
					  get_power_factor()
```

- `get_current()` liefert das gewählte Szenario, ohne Auswahl das erste nach `sort_order`. Später kann jeder Code darüber nachsehen, welches Szenario läuft, z. B. für die Landschaft oder die Auswertung.
- Der `ScenarioSelector` überträgt die Werte in `_ready()` per `call_deferred`. So ist egal, wo er im Szenenbaum steht. Danach ruft er `EnergyMix.reset()` auf, damit der Seed schon für die erste Runde gilt, und `InventoryBar.refresh()`.
- Verbotene Typen stehen in `InventoryBar.hidden_plants` und fehlen dadurch in der Leiste. Ein leerer Reiter verschwindet. Der `EnergyMix` legt weiterhin für jeden Typ eine Anlage an. Sie bleibt bei 0 Einheiten.

## Einträge der Szenario-JSON

Alle Felder, die eine Szenario-JSON enthalten kann. Typ, Standardwert und Sonderfälle stehen in der [Feldreferenz](_base/scenario_schema.md). Ein fehlendes Feld erzeugt eine Warnung, und der Standardwert gilt.

### Kopf

| Eintrag | Erklärung | Wirkung |
|---|---|---|
| `schema_version` | Version des JSON-Formats, aktuell `1`. Für spätere Format-Änderungen. | wird noch nicht ausgewertet |
| `id` | Eindeutiger technischer Name, klein und mit `_`. Fehlt er, gilt der Dateiname. Eine doppelte `id` wird übersprungen. | Schlüssel für `ScenarioRegistry.get_by_id()` und `select()` |
| `display_name` | Name, den der Spieler im Dropdown sieht. | Eintrag im Dropdown |
| `sort_order` | Reihenfolge im Dropdown, aufsteigend. Das Szenario mit der kleinsten Zahl ist beim Start gewählt. | Dropdown |
| `description` | Beschreibung des Szenarios für den Spieler. | Tooltip am Dropdown |
| `info` | Liste kurzer Hinweise („viel Sonne“, „wenig Wind“). | Aufzählung im Tooltip |

### `simulation` – Ablauf einer Runde

| Eintrag | Erklärung | Wirkung |
|---|---|---|
| `round_hours` | Simulierte Dauer einer Runde in Stunden. | `GameFlow.round_hours` |
| `start_hour` | Uhrzeit beim Rundenstart, z. B. `6.5` = 06:30 Uhr. | `ClockDisplay.start_hour` |
| `tick_hours` | Spielzeit pro Rechenschritt in Stunden (`0.05` = 3 min). Je kleiner, desto genauer die Rechnung. Die Rundendauer in Echtzeit ändert sich dadurch nicht. | `EnergyMix.tick_hours` |
| `round_minutes` | Dauer einer Runde in Echtzeit-Minuten. Zusammen mit `round_hours` und `tick_hours` ergibt sich das Spieltempo: `ticks_per_second = (round_hours / tick_hours) / (round_minutes * 60)`. | `EnergyMix.ticks_per_second` (berechnet über `ScenarioDefinition.get_ticks_per_second()`) |
| `random_seed` | Zentraler Seed für alle Zufallswerte der Erzeuger. Gleicher Seed, gleiche Runde. | `EnergyMix.random_seed` |

### `plants` – Anlagentypen

Ein Objekt je Typ-`id` aus `res://plants/`, z. B. `"hydro": { ... }`. Fehlt ein Typ, ist er erlaubt und hat den Faktor 1. Eine unbekannte `id` erzeugt eine Warnung.

| Eintrag | Erklärung | Wirkung |
|---|---|---|
| `plants.<id>.allowed` | `false` verbietet den Typ in diesem Szenario. Nur ein ausdrückliches `false` verbietet. | Typ fehlt in der Inventarleiste (`InventoryBar.hidden_plants`) |
| `plants.<id>.power_factor` | Leistungsfaktor des Typs in diesem Szenario, z. B. `0.5` für Wasserkraft bei niedrigem Wasserstand. | noch ohne Wirkung |

### Spielfeld, Landschaft und Wetter

| Eintrag | Erklärung | Wirkung |
|---|---|---|
| `build_area` | Bebaubare Fläche als `[x, y]` in Rasterfeldern. | noch ohne Wirkung |
| `landscape.ground_color` | Bodenfarbe als HTML-Farbe, z. B. `"#00ff00"`. | noch ohne Wirkung |
| `landscape.grass` | Pfad zum Gras-Mesh, relativ zu `res://scenarios/`. | noch ohne Wirkung |
| `landscape.background` | Pfad zum Hintergrundbild, relativ zu `res://scenarios/`. `null` = keins. | noch ohne Wirkung |
| `weather` | Wetter des Szenarios. Die Struktur wird mit dem Wetter-Feature festgelegt, bis dahin `{}`. | noch ohne Wirkung |

Die Inspector-Werte `round_hours`, `tick_hours`, `ticks_per_second` (im Szenario aus `round_minutes` berechnet) und `random_seed` in `scenes/level.tscn` gelten nur noch, wenn es kein Szenario gibt.

## Neues Szenario anlegen

1. `ravensburg.json` kopieren und umbenennen, z. B. `schule.json`. Der Dateiname sollte der `id` entsprechen.
2. `id`, `display_name`, `sort_order` und die Werte anpassen (siehe [`_base/scenario_schema.md`](_base/scenario_schema.md)).
3. Spiel starten. Das Szenario steht im Dropdown. Warnungen zu fehlenden Feldern oder unbekannten Typen stehen in der Ausgabe.

Ein Szenario lässt sich vorerst ausblenden, indem man einen Punkt vor den Dateinamen setzt (`.schule.json`).

## Tests

Aufruf im Projektordner:

```bash
godot --headless --path . --script res://scenarios/_tests/run_tests.gd
```

**Was geprüft wird:**
- Ravensburg wird gefunden und hat die Werte des bisherigen Spiels.
- Ohne Auswahl ist das erste Szenario gewählt, `select()` wechselt, eine unbekannte id ändert nichts.
- Fixtures: fehlende Felder → Standardwerte und `id` aus dem Dateinamen, Verbot und Leistungsfaktor, unbekannter Typ, fehlendes Asset, kein JSON-Objekt, doppelte `id`, Punkt-Datei, Sortierung.

## Noch offen

- Konkrete Szenarien und ihre Werte (Team / Product Owner).
- Anwenden von `power_factor`, `build_area`, `landscape` und `weather`.
- **Vorschlag:** Der Verbrauch (`EnergyMix.demand_kw`) steht nicht auf der Karte, wäre aber ein naheliegender Szenario-Wert (Krankenhaus ≠ Bauernhof).
- **Export:** Im exportierten Build prüfen, dass alle Szenario-JSONs gefunden werden (wie bei den Anlagen).
