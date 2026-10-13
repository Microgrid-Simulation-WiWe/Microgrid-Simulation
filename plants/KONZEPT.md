# Konzept: Anlagentypen (Erzeuger und Speicher)

Stand: 12.10.2026, erste Umsetzung in `res://plants/`. Ein Ablauf, wie ein neuer Typ angelegt wird, steht in [`HOW_TO.md`](HOW_TO.md), die Feldreferenz in [`_base/plant_schema.md`](_base/plant_schema.md).

## Ziel

Das Microgrid-Planspiel (Godot 4.7, 3D, GDScript) braucht ein einheitliches, erweiterbares Modell für seine Anlagentypen:

| Erzeuger | Speicher |
|---|---|
| Windrad | Batteriespeicher |
| Solar | Pumpspeicher |
| Wasser (Laufwasser) | |
| Kohle | |
| Gas | |
| Atom | |

**Anforderungen:**
- Jede Anlage hat eine Leistungsgrenze.
- Der Spieler steuert sie von Hand: Sollwert, Drosselung, Ein/Aus.
- Ihre Leistung hängt von Einflussgrößen ab: Sonne, Wind, Wasser, Zufall.
- Woher Wetter- und Zeitdaten kommen, gehört **nicht** zu diesem Teil.

## Festgelegte Entscheidungen

- **GDScript.** Gerechnet wird **aggregiert pro Typ** und nicht pro gebautem Gebäude.
- **Dynamik:**
  - Mindestlast.
  - Rampe in **%-Leistungspunkten pro Tick**.
- **Alle Regelungen macht der Spieler von Hand.** Das Spiel schaltet nichts automatisch, auch die Speicher nicht.
- **Zuordnung:**
  - Laufwasser ist ein einfacher Generator.
  - Pumpspeicher wird wie eine Batterie behandelt.
  - Verbraucher kommen später.
- **Ein Ordner pro Typ** mit einer `plant.json` (Standardwerte und Asset-Verweise) und allen Dateien des Typs. Ein neuer Typ braucht keinen Code.
- **Kein Eingriff in bestehende Dateien:** Deshalb ist die `PlantRegistry` eine statische Klasse statt eines Autoloads. Ein Autoload hätte eine Änderung an `project.godot` erfordert.

## 1. Drei Ebenen pro Typ

| Ebene | Was | Godot-Form | Wie oft |
|---|---|---|---|
| **Steckbrief** | Standardwerte + Verweise auf Icon, Modell, Texturen, Sounds, Effekte | `plant.json` → geladen als `PlantDefinition` (Resource) | 1 pro Typ |
| **Logik** | Sollwert, Rampe, Verfügbarkeit, Ladestand → tatsächliche Leistung | `GeneratorPlant` / `StoragePlant` (Node) | 1 pro Typ |
| **Darstellung** | Modell, Animation, Sound, Effekte | generische Basis-Szene, wird aus der JSON bestückt | pro gebautem Gebäude |

- Gebäude rechnen nichts. Sie **lesen** nur den Zustand ihrer Anlage, etwa für die Rotordrehzahl, die Lautstärke oder die Füllanzeige.
- **JSON statt XML:** Godot liest JSON eingebaut (`JSON.parse_string`). Für XML gibt es nur den Low-Level-`XMLParser`.

## 2. Klassen

GDScript-`@abstract` (ab Godot 4.5) verhindert, dass Basisklassen direkt benutzt werden.

```
plant.json ──► PlantRegistry (statisch: get_all(), get_by_id(), scan())
                 │ liest alle res://plants/*/plant.json, prüft, sortiert
                 ▼
DATEN (Resource)                 LOGIK (Node)                  DARSTELLUNG (Node3D)
@abstract PlantDefinition        @abstract PowerPlant          @abstract PlantBuilding
 ├─ GeneratorDefinition ───────► ├─ GeneratorPlant ◄────────── ├─ GeneratorBuilding
 └─ StorageDefinition   ───────► └─ StoragePlant   ◄────────── └─ StorageBuilding
   load_from_dict(), create_plant() tick(), Steuerung             setup(), liest Zustand
```

- **Zwei Logik-Klassen reichen für alle Typen.** Die Unterschiede stecken nur in den Werten der `plant.json`.
- `type` in der JSON entscheidet über die Definitions-Klasse. `create_plant()` liefert dann die passende Logik.
- **`EnergyMix`** (Node) hat drei Aufgaben:
  - Er legt beim Start je Typ eine Logik-Instanz als Kind an.
  - Er taktet alle Anlagen mit `tick()`, entweder manuell oder über `ticks_per_second`.
  - Er summiert `total_power_mw`.
- **Bauphase:** `EnergyMix.build(id)` erhöht `unit_count` und liefert das passende Gebäude.

## 3. Steuerschnittstelle `PowerPlant`

| Eigenschaft | Bedeutung |
|---|---|
| `setpoint` | Sollwert in % der installierten Leistung. Erzeuger 0..100, Speicher −100 (laden) .. +100 (entladen). Start: 0. |
| `enabled` | Ein/Aus. Aus = Leistung fährt mit der Rampe auf 0. |
| `unit_count` | Anzahl gebauter Einheiten (setzt die Bauphase). |
| `availability_modifier` | 0..1 für Ereignisse und Störungen (z. B. Viehplage). |
| `installed_power_mw`, `available_power_mw`, `actual_power_mw` | Zustand, im Inspector schreibgeschützt. `actual` ist + bei Einspeisung und − bei Aufnahme. |
| `state_of_charge` | Nur Speicher: Ladestand 0..1. |
| Signal `state_changed(plant)` | Nach jedem Tick, z. B. für UI und Gebäude. |

**Ein Tick beim Erzeuger:**
1. `P_inst = unit_count · unit_power_mw`
2. `P_avail = P_inst · Kennlinie(Einflussgröße) · availability_modifier · (1 + Rauschen)`, begrenzt auf 0..P_inst
3. Ziel:
   - Ist die Anlage aus, ist das Ziel 0.
   - Sonst `min(max(setpoint, min_load) · P_inst, P_avail)`.
4. Rampe: höchstens `ramp_per_tick` %-Punkte von `P_inst` Richtung Ziel.
5. Harte Grenze `min(P_actual, P_avail)`. Fällt das Wetter weg, sinkt die Leistung sofort.

Bei Erneuerbaren wirkt der Sollwert damit als **Drosselung**. Atom bleibt mindestens bei 50 %, solange es an ist.

**Ein Tick beim Speicher:**
- Der Sollwert wird mit der Rampe angefahren.
- Die Leistung ist begrenzt durch Ladestand und Wirkungsgrad:
  - Entladen höchstens `soc · Kapazität · η / tick_hours`.
  - Laden höchstens `(1 − soc) · Kapazität / (η · tick_hours)`.
- Leer oder voll heißt 0 MW. Das ist Physik und keine automatische Regelung.

**Einflussgrößen (`SimInputs`):**
- Eine Resource mit `solar_irradiance`, `wind_speed`, `water_flow`, `cooling_water` und `time_of_day_h`.
- Der `EnergyMix` reicht sie pro Tick an alle Anlagen weiter. Später setzt sie das Wetter-System.

**Zufall:** glattes `FastNoiseLite`-Rauschen. Der Seed (`EnergyMix.noise_seed`) macht Szenarien reproduzierbar.

## 4. Ordnerstruktur

```
res://plants/
├─ KONZEPT.md  HOW_TO.md
├─ _base/          Basisklassen, Basis-Szenen, plant_schema.md
├─ _tests/         run_tests.gd + fixtures/ (absichtlich fehlerhafte plant.json)
├─ solar/ wind/ hydro/ coal/ gas/ nuclear/ battery/ pumped_hydro/
│    └─ plant.json (+ später icon.png, models/, textures/, sounds/, effects/)
```

- Ordner, die mit `_` beginnen, enthalten keine `plant.json` direkt und werden deshalb nicht als Typ erkannt.
- Die Asset-Pfade in den `plant.json` sind noch leer, weil es noch keine Grafiken und Sounds gibt. Bis dahin zeigt ein Gebäude eine graue Platzhalter-Box.

## 5. Startwerte (Platzhalter, Balancing später)

| Typ | `type` | MW/Einheit | Mindestlast | Rampe %/Tick | Einfluss | Zufall | Baupunkte | Felder |
|---|---|---|---|---|---|---|---|---|
| Solar | generator | 1 | 0 | 100 | `solar_irradiance` | ±5 % | 2 | 2×1 |
| Wind | generator | 2 | 0 | 100 | `wind_speed` (0 unter 3 m/s, voll ab 12 m/s, 0 über 25 m/s) | ±10 % | 3 | 1×1 |
| Wasser | generator | 1 | 0 | 100 | `water_flow` | ±2 % | 3 | 1×1 |
| Kohle | generator | 5 | 40 % | 2 | – | – | 2 | 2×2 |
| Gas | generator | 3 | 20 % | 10 | – | – | 2 | 1×1 |
| Atom | generator | 10 | 50 % | 1 | `cooling_water` | – | 5 | 2×2 |
| Batterie | storage | 2 MW / 4 MWh | – | 100 | η 95 %/95 % | – | 2 | 1×1 |
| Pumpspeicher | storage | 5 MW / 40 MWh | – | 100 | η 88 %/88 % | – | 4 | 2×2 |

## 6. Inspector und JSON

- **Standardwerte** stehen nur in der `plant.json`. Das ist die einzige Quelle, es gibt keine doppelte Pflege.
- **Zur Laufzeit** sind Definitionen und Anlagen im **Remote-Inspector** sichtbar und live änderbar. Das wird nicht gespeichert.
- **Im Inspector** gepflegt werden:
  - die globalen Simulationswerte am `EnergyMix`: `tick_hours`, `ticks_per_second`, `noise_seed`, `inputs`
  - die Basis-Szenen

## 7. Tests

Aufruf im Projektordner:

```bash
godot --headless --path . --script res://plants/_tests/run_tests.gd
```

**Was geprüft wird:**
- Registry und Sortierung
- Wind-Kennlinie mit Sturmabschaltung
- Solar bei Nacht
- Atom-Mindestlast und -Rampe (50 → 100 % in 50 Ticks)
- `unit_count` 0
- Gas Ein/Aus mit Rampe
- Speicher: Entladen bis leer, Laden mit Wirkungsgrad
- `EnergyMix`, `build()` und Gebäude mit Platzhalter
- Ladefehler: fehlende Felder, unbekannter `type`, doppelte `id`, fehlende Assets

## 8. Stand der Umsetzung

**Umgesetzt:**
- alles aus den Abschnitten 1–7

**Bewusst noch nicht umgesetzt** (abgestimmt, kommt bei Bedarf):
- Editor-Vorschau eines Typs ohne Spielstart (`preview_json`, bräuchte `@tool` in den Basisskripten)
- Button „In JSON speichern“ im Inspector
- eigene Rechenlogik pro Typ (`"script"`-Feld in der JSON)
- automatisches Anwenden von `assets.textures`
- Debug-Szene mit Schiebereglern
- `co2_t_per_mwh` und `cost_per_mwh` für eine spätere Bewertung

**Noch offen (Team / Product Owner):**
1. **Tick-Länge und Rundendauer:** Wie viel Sim-Zeit ist ein Tick? Davon hängen Rampenwerte und Speicher-Energie ab.
2. **Konkrete Werte:** Leistungen, Baupunkte und `area_usage`.
3. **Export:** Im exportierten Build prüfen, dass alle `plant.json` gefunden werden. Gegebenenfalls `*.json` im Export-Filter „Nicht-Ressourcen-Dateien“ ergänzen.
