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

## Was schon wirkt

| Karte | JSON | Wirkung |
|---|---|---|
| Name, Beschreibung | `display_name`, `description` | Eintrag und Tooltip im Dropdown |
| Stats für den Spieler | `info` | Aufzählung im Tooltip |
| Zeitraum einer Runde | `simulation.round_hours` | `GameFlow.round_hours` |
| Tickspeed | `simulation.tick_hours`, `simulation.ticks_per_second` | `EnergyMix` |
| Startuhrzeit | `simulation.start_hour` | `ClockDisplay.start_hour` |
| Seed | `simulation.random_seed` | `EnergyMix.random_seed` |
| Erzeuger erlauben / verbieten | `plants.<id>.allowed` | Inventarleiste |
| Erzeugerleistung je Szenario | `plants.<id>.power_factor` | noch ohne Wirkung |
| Verfügbare Baufläche | `build_area` | noch ohne Wirkung |
| Landschaft + Hintergrundbild | `landscape.*` | noch ohne Wirkung |
| Wetter | `weather` | noch ohne Wirkung |

Die Inspector-Werte `round_hours`, `tick_hours`, `ticks_per_second` und `random_seed` in `scenes/level.tscn` gelten nur noch, wenn es kein Szenario gibt.

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
- Die neuen Klassen fehlen noch im Klassendiagramm `docs/klassendiagramm.svg`.
