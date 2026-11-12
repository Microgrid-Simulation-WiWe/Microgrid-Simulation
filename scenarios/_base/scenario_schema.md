# Feldreferenz Szenario-JSON

Jedes Szenario ist eine eigene JSON-Datei direkt in `res://scenarios/`, z. B. `ravensburg.json`. JSON erlaubt keine Kommentare, deshalb stehen die Erklärungen hier. Das Konzept steht in [`../KONZEPT.md`](../KONZEPT.md).

- **Pfade** sind immer **relativ zu `res://scenarios/`**, z. B. `"../assets/meshes/grass.res"`.
- **Fehlt ein Feld**, gibt es beim Start eine Warnung mit Dateiname, und der Standardwert wird verwendet.
- **`""` oder `null`** bedeuten „bewusst leer“. Das erzeugt keine Warnung.
- **Wirkung:** Felder mit „noch ohne Wirkung“ werden geladen und stehen in der `ScenarioDefinition` bereit, das Spiel nutzt sie aber noch nicht.

## Kopf

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `schema_version` | Zahl | – | Version dieses Formats (aktuell `1`). Wird noch nicht ausgewertet. |
| `id` | Text | Dateiname ohne `.json` | Eindeutiger technischer Name, klein und mit `_`. Sollte dem Dateinamen entsprechen. |
| `display_name` | Text | `id` | Name im Dropdown. |
| `sort_order` | Zahl | `0` | Reihenfolge im Dropdown, aufsteigend. Das erste Szenario ist beim Spielstart gewählt. |
| `description` | Text | `""` | Beschreibung, erscheint als Tooltip am Dropdown. |
| `info` | Liste von Texten | `[]` | Kurze Hinweise für den Spieler, z. B. `["viel Sonne", "wenig Wind"]`. Erscheinen als Aufzählung im Tooltip. |

## `simulation` – Ablauf einer Runde

Diese Werte überschreiben beim Spielstart die Werte aus `scenes/level.tscn`.

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `round_hours` | Zahl | `24` | Simulierte Dauer einer Runde in Stunden (→ `GameFlow.round_hours`). |
| `start_hour` | Zahl | `12` | Uhrzeit beim Rundenstart, z. B. `6.5` = 06:30 Uhr (→ `ClockDisplay.start_hour`). |
| `tick_hours` | Zahl | `0.05` | Simulierte Dauer eines Ticks in Stunden, `0.05` = 3 min (→ `EnergyMix.tick_hours`). |
| `round_minutes` | Zahl | `8` | Dauer einer Runde in Echtzeit-Minuten, ohne Pausen. Daraus wird `EnergyMix.ticks_per_second` berechnet. |
| `random_seed` | Zahl | `1` | Zentraler Seed für alle Zufallswerte (→ `EnergyMix.random_seed`). |

`tick_hours` legt fest, wie fein gerechnet wird, `round_minutes`, wie lange die Runde in Echtzeit dauert. Das Spieltempo wird daraus berechnet: `ticks_per_second = (round_hours / tick_hours) / (round_minutes * 60)`. Mit den Standardwerten sind das 480 Ticks in 480 s = 1 Tick pro Sekunde. Ein kleineres `tick_hours` rechnet genauer, ändert die Rundendauer aber nicht.

## `plants` – Anlagentypen

Ein Objekt je Typ-`id` aus `res://plants/`. Typen, die fehlen, sind erlaubt und haben den Faktor 1. Eine unbekannte `id` erzeugt eine Warnung.

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `allowed` | `true`/`false` | `true` | `false` = Typ fehlt in diesem Szenario in der Inventarleiste. Nur ein ausdrückliches `false` verbietet. |
| `power_factor` | Zahl | `1` | Leistungsfaktor in diesem Szenario, z. B. `0.5` für Wasserkraft bei niedrigem Wasserstand. Skaliert die installierte Leistung je Einheit. |

## Spielfeld und Landschaft (noch ohne Wirkung)

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `build_area` | [x, y] | `[60, 60]` | Bebaubare Fläche in Rasterfeldern (1 Feld = 1 Welteinheit). Das heutige Spielfeld ist 60 × 60. |
| `landscape.ground_color` | Text | `"#00ff00"` | Bodenfarbe als HTML-Farbe. |
| `landscape.grass` | Pfad | `""` | Mesh für das Gras (heute `assets/meshes/grass.res`). |
| `landscape.background` | Pfad | `""` | Hintergrundbild. |
| `weather` | Objekt | `{}` | Wetter. Die Struktur wird mit dem Wetter-Feature festgelegt. |
