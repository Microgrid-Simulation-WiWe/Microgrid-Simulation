# Feldreferenz `plant.json`

Jeder Anlagentyp hat genau eine `plant.json` in seinem Ordner `res://plants/<id>/`. JSON erlaubt keine Kommentare, deshalb stehen die Erklärungen hier.

- **Pfade** sind immer **relativ zum Typ-Ordner**, z. B. `"models/wind.glb"`.
- **Fehlt ein Feld**, gibt es beim Start eine Warnung mit Dateiname, und der Standardwert wird verwendet.
- **`""` oder `null`** bedeuten „bewusst leer“. Das erzeugt keine Warnung.

## Kopf

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `schema_version` | Zahl | – | Version dieses Formats (aktuell `1`). Ist für spätere Erweiterungen gedacht und wird noch nicht ausgewertet. |
| `id` | Text | Ordnername | Eindeutiger technischer Name, klein und mit `_` (z. B. `pumped_hydro`). Sollte dem Ordnernamen entsprechen. |
| `display_name` | Text | `id` | Name im Spiel (z. B. „Pumpspeicherkraftwerk“). |
| `type` | Text | – | **Pflichtfeld.** `"generator"` (Erzeuger) oder `"storage"` (Speicher). Bestimmt die Logik-Klasse. |
| `sort_order` | Zahl | `0` | Reihenfolge im Baumenü, aufsteigend. |

## `build` – Bauphase

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `cost` | Zahl | `0` | Baupunkte pro Einheit. |
| `area_usage` | [x, y] | `[1, 1]` | Belegte Felder auf dem Raster. |

## `power` – Leistung und Dynamik

| Feld | Typ | Standard | Gilt für | Bedeutung |
|---|---|---|---|---|
| `unit_power_mw` | Zahl | `0` | alle | Nennleistung **pro gebauter Einheit** in MW. Installierte Leistung = Anzahl × diesem Wert. |
| `ramp_per_tick` | Zahl | `100` | alle | Wie viele %-Punkte der installierten Leistung sich die Leistung pro Tick höchstens ändert. `100` = sofort, `1` = sehr träge (0 → 100 % in 100 Ticks). |
| `min_load` | Zahl | `0` | Erzeuger | Mindestlast in %, solange die Anlage an ist. Ein kleinerer Sollwert wird darauf angehoben. |
| `noise_level` | Zahl 0..1 | `0` | Erzeuger | Zufallsschwankung als Anteil der installierten Leistung, `0` = aus. Standardwert für alle Anlagen dieses Typs; kann pro Anlage überschrieben werden. |

## `storage` – Speicher (nur `type: "storage"`)

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `unit_capacity_mwh` | Zahl | `0` | Speicherkapazität pro Einheit in MWh. |
| `charge_efficiency` | 0.01..1 | `1` | Wirkungsgrad beim Laden. |
| `discharge_efficiency` | 0.01..1 | `1` | Wirkungsgrad beim Entladen. |
| `initial_soc` | 0..1 | `0.5` | Ladestand beim Start. |

## `assets` – Dateien des Typs

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `icon` | Pfad | `""` | Icon für das Baumenü (z. B. `icon.png`). |
| `model` | Pfad | `""` | 3D-Modell (`.glb`/`.tscn`). Leer = graue Platzhalter-Box in Größe `area_usage`. |
| `textures` | {Name: Pfad} | `{}` | Zusätzliche Texturen. Werden geladen, aber **noch nicht automatisch angewendet**. |
| `animation` | Text | `""` | Name der Animation im Modell (oder im AnimationPlayer der Szene). Wird in Schleife abgespielt, das Tempo folgt der Auslastung. |
| `sounds` | {Name: Pfad} | `{}` | `loop` = Dauerton, die Lautstärke folgt der Auslastung. Weitere Namen sind für später frei. |
| `effects` | [Pfad, …] | `[]` | Effekt-Szenen (z. B. Partikel), werden unter `Effects` eingehängt. |
| `scene` | Pfad / `null` | `null` | Eigene Gebäude-Szene statt der Standard-Szene. Nur für Sonderfälle; sie muss von `_base/generator_building_base.tscn` bzw. `_base/storage_building_base.tscn` erben. |

## `visual` – Feintuning der Darstellung

| Feld | Typ | Standard | Bedeutung |
|---|---|---|---|
| `scale` | Zahl | `1.0` | Skalierung des Modells. |
| `offset` | [x, y, z] | `[0, 0, 0]` | Verschiebung des Modells. |
| `anim_speed` | [min, max] | `[0.2, 1.5]` | Animationstempo bei geringer bzw. voller Auslastung. Bei 0 % steht die Animation. |
| `volume_db` | [min, max] | `[-30, -6]` | Lautstärke in dB bei geringer bzw. voller Auslastung. Bei 0 % ist der Ton pausiert. |
