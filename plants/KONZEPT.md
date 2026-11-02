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
- Ihre Leistung wird über den Sollwert gesteuert. Zusätzlich kann eine Zufallsschwankung von außen eingestellt werden. Wetter wirkt noch nicht.

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
- **`EnergyMix`** (Node) hat sechs Aufgaben:
  - Er legt beim Start je Typ eine Logik-Instanz als Kind an.
  - Er taktet alle Anlagen mit `tick()`, entweder manuell oder über `ticks_per_second`. Ist `running` aus, steht die Simulation still.
  - Er summiert `total_power_mw`.
  - Er summiert die Energiebilanz `energy_balance_kwh`.
  - Er berechnet die Netzfrequenz `frequency_hz` (nur noch intern).
  - `reset()` setzt ihn auf den Rundenstart zurück: Uhr (`tick_count`), Energiebilanz, Frequenz und den Zustand aller Anlagen. Gebaute Einheiten und Sollwerte bleiben.
- **Bauphase:** `EnergyMix.build(id)` erhöht `unit_count` und liefert das passende Gebäude.
- **Bauen und Simulation** sind getrennt. Das steuert `scenes/game_flow/game_flow.gd` (`GameFlow`) in der Level-Szene:
  - In der Bauphase ist `running` aus. Sichtbar sind nur die Knoten in `build_ui` (Inventarleiste).
  - Der Knopf „Simulation starten“ schaltet `running` an und zeigt `simulation_ui` (Sollwerte, Uhr, Erzeugung, Leistungsbilanz).
  - Eine Runde ist ein simulierter Tag (`round_hours`, Standard 24 h). Danach oder über „Simulation beenden“ kommt das Signal `round_finished(completed)`, anschließend `reset()` und zurück in die Bauphase. Jede Runde beginnt also von vorne.
  - `round_finished` ist der Anknüpfpunkt für das Dashboard nach jeder Runde und für ein späteres Spielende.
- **Energiebilanz:** Nach jedem Tick kommt `(total_power_mw · 1000 − demand_kw) · tick_hours` zu `energy_balance_kwh` dazu.
  - Plus heißt, es wurde mehr erzeugt als verbraucht. Minus heißt Unterdeckung. Ziel ist eine Bilanz nahe 0.
  - Ein ladender Speicher hat negative Leistung und senkt die Bilanz. Einen Überschuss kann man also einspeichern und später wieder abgeben.
  - `demand_kw` ist ein Platzhalter-Verbrauch in kW (Standard 20 kW), bis es Verbraucher gibt.
  - Die Bilanz wird nur intern mitgeführt und ist im Inspector sichtbar. Später kann sie z. B. für das Spielende oder eine Auswertung genutzt werden.
- **Anzeige der Leistungsbilanz:** `scripts/power_balance_display.gd` zeigt Erzeugung − `demand_kw` mit Vorzeichen, unter 1 MW in kW, darüber in MW. Der Wert reagiert beim nächsten Tick, anders als die aufsummierte kWh-Bilanz.
  - Dazu kommt ein Balken von −`demand_kw` bis +`demand_kw`: grün bis ±10 % des Verbrauchs, gelb bis ±30 %, sonst rot. Die Stufen sind Platzhalter-Exports (`green_band`, `yellow_band`).
  - Bei `demand_kw` 0 bleibt die Markierung in der Mitte.
- **Netzfrequenz:** Sie entscheidet nicht mehr über den Spielablauf, wird aber weiter mitgeführt und ist im Inspector sichtbar. Nach jedem Tick läuft `frequency_hz` um den Anteil `frequency_response` auf `50 Hz + hz_per_imbalance · (total_power_mw · 1000 − demand_kw) / demand_kw` zu.
  - Bei zu viel Erzeugung steigt sie, bei zu wenig fällt sie. Sie reagiert träge wie eine Schwungmasse.
  - Bei `demand_kw` 0 gibt es kein Ungleichgewicht.
  - Die frühere Hz-Anzeige `scripts/frequency_display.gd` (Balken 48–52 Hz) wurde am 29.10.2026 entfernt. Der Code steht in der Git-History.

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
| `reset()` | Rundenstart: Leistung 0, `availability_modifier` 1, Speicher-Ladestand auf `initial_soc`. `unit_count`, `setpoint` und `enabled` bleiben. |

**Ein Tick beim Erzeuger:**
1. `P_inst = unit_count · unit_power_mw`
2. `P_avail = P_inst · availability_modifier`, begrenzt auf 0..P_inst
3. Ziel:
   - Ist die Anlage aus, ist das Ziel 0.
   - Sonst `min(max(setpoint, min_load) · P_inst, P_avail)`.
4. Rampe: höchstens `ramp_per_tick` %-Punkte von `P_inst` Richtung Ziel.
5. Zufall (nur Erzeuger): In jedem Tick wird ein Zufallswert gleichverteilt in −1..1 gezogen, auch wenn die Anlage aus ist. Ist die Leistung > 0, wird `noise_level · P_inst · Zufallswert` addiert. `noise_level` 0 = aus.
6. Harte Grenze `0..P_avail`. Sinkt die Verfügbarkeit (Störung), sinkt die Leistung sofort.

Atom bleibt mindestens bei 50 %, solange es an ist.

**Ein Tick beim Speicher:**
- Der Sollwert wird mit der Rampe angefahren.
- Die Leistung ist begrenzt durch Ladestand und Wirkungsgrad:
  - Entladen höchstens `soc · Kapazität · η / tick_hours`.
  - Laden höchstens `(1 − soc) · Kapazität / (η · tick_hours)`.
- Leer oder voll heißt 0 MW. Das ist Physik und keine automatische Regelung.

**Wetter** ist vorerst entfernt (siehe Abschnitt 8). Die Zufallsschwankung wird pro Anlage von außen gesetzt (`noise_level`, Standard 0).

**Zufall und Seed:**
- Alle Zufallswerte des Spiels kommen aus dem zentralen Seed `random_seed` am `EnergyMix` (Inspector, Gruppe „Zufall“, Standard 1). Gleicher Seed und gleiche Programmversion heißt: auf jedem Rechner dieselben Ereignisse.
- Jede Zufallsfunktion addiert ihren festen Wert auf den Seed und bekommt so ihre eigene Zahlenfolge. Die Werte stehen als `SEED_OFFSET_*` im `EnergyMix`. `create_rng(offset)` liefert den passenden Zufallsgenerator.
- Bei jedem Rundenstart (`reset()`) beginnen alle Folgen von vorne, jede Runde hat also dieselben Zufallswerte. Eine Änderung am Seed wirkt ab dem nächsten Rundenstart.
- Erzeuger ziehen in jedem Tick einen Wert, auch wenn sie aus sind. Sonst würden sich die Werte verschieben, je nachdem welche Anlagen der Spieler laufen lässt.

| Zufallsfunktion | Fester Wert | Datei |
|---|---|---|
| Leistungsrauschen aller Erzeuger (eine gemeinsame Folge) | `SEED_OFFSET_GENERATOR_NOISE` = 1000 | `plants/_base/generator_plant.gd` |
| Position beim Test-Knopf „Windrad bauen“ | `SEED_OFFSET_BUILD_POSITION` = 2000 | `scripts/build_wind_button.gd` |

Neue Zufallsfunktion (z. B. Störungen): einen neuen festen Wert im `EnergyMix` anlegen und den Generator über `create_rng()` holen. Nicht verwenden: die globalen Funktionen `randf()`, `randi()`, `randf_range()`, `randi_range()`, `randomize()` und `seed()` sowie `Array.shuffle()` und `Array.pick_random()`. Sie nutzen den globalen Generator, den Godot bei jedem Start neu würfelt.

Die Gras-Verteilung (`scripts/grass_scatter.gd`) ist reine Optik und behält ihren eigenen Seed.

## 4. Ordnerstruktur

```
res://plants/
├─ KONZEPT.md  HOW_TO.md
├─ _base/          Basisklassen, Basis-Szenen, plant_schema.md
├─ _tests/         run_tests.gd + fixtures/ (absichtlich fehlerhafte plant.json)
├─ solar/ wind/ hydro/ coal/ gas/ nuclear/ battery/   .pumped_hydro/ (ausgeblendet)
│    └─ plant.json (+ später icon.png, models/, textures/, sounds/, effects/)
```

- Ordner, die mit `_` beginnen, enthalten keine `plant.json` direkt und werden deshalb nicht als Typ erkannt.
- Ordner, die mit `.` beginnen, überspringt die Registry. So ist ein Typ vorerst ausgeblendet, aktuell `.pumped_hydro`. Der Godot-Editor zeigt solche Ordner nicht an und exportiert sie nicht.
- Die Asset-Pfade in den `plant.json` sind noch leer, weil es noch keine Grafiken und Sounds gibt. Bis dahin zeigt ein Gebäude eine graue Platzhalter-Box.

## 5. Startwerte (Platzhalter, Balancing später)

| Typ | `type` | MW/Einheit | Mindestlast | Rampe %/Tick | Wirkungsgrad | Baupunkte | Felder |
|---|---|---|---|---|---|---|---|
| Solar | generator | 1 | 0 | 100 | – | 2 | 2×1 |
| Wind | generator | 2 | 0 | 100 | – | 3 | 1×1 |
| Wasser | generator | 1 | 0 | 100 | – | 3 | 1×1 |
| Kohle | generator | 5 | 40 % | 2 | – | 2 | 2×2 |
| Gas | generator | 3 | 20 % | 10 | – | 2 | 1×1 |
| Atom | generator | 10 | 50 % | 1 | – | 5 | 2×2 |
| Batterie | storage | 2 MW / 4 MWh | – | 100 | η 95 %/95 % | 2 | 1×1 |
| Pumpspeicher (ausgeblendet) | storage | 5 MW / 40 MWh | – | 100 | η 88 %/88 % | 4 | 2×2 |

## 6. Inspector und JSON

- **Standardwerte** stehen nur in der `plant.json`. Das ist die einzige Quelle, es gibt keine doppelte Pflege.
- **Zur Laufzeit** sind Definitionen und Anlagen im **Remote-Inspector** sichtbar und live änderbar. Das wird nicht gespeichert.
- **Im Inspector** gepflegt werden:
  - die globalen Simulationswerte am `EnergyMix`: `tick_hours`, `ticks_per_second`
    - In `scenes/level.tscn` ist `tick_hours` 0,05 h (3 min). Bei 1 Tick pro Sekunde dauert ein simulierter Tag (480 Ticks) 8 min, passend zu den 5–10 min pro Runde aus dem Sprint Review vom 26.10.2026.
  - die Rundenlänge am `GameFlow`: `round_hours`
  - der Verbrauch am `EnergyMix`: `demand_kw` (Energiebilanz `energy_balance_kwh` nur lesbar)
  - der zentrale Seed am `EnergyMix`: `random_seed` (siehe Abschnitt 3)
  - die Netzfrequenz am `EnergyMix`: `hz_per_imbalance`, `frequency_response`
  - die Basis-Szenen

## 7. Tests

Aufruf im Projektordner:

```bash
godot --headless --path . --script res://plants/_tests/run_tests.gd
```

**Was geprüft wird:**
- Registry und Sortierung
- Wind folgt dem Sollwert (100 % / 50 %) und dem Störfaktor
- Atom-Mindestlast und -Rampe (50 → 100 % in 50 Ticks)
- `unit_count` 0
- Gas Ein/Aus mit Rampe
- Speicher: Entladen bis leer, Laden mit Wirkungsgrad
- `EnergyMix`, `build()` und Gebäude mit Platzhalter
- Netzfrequenz: 50 Hz bei Gleichgewicht, träges Fallen bei Unterdeckung, `demand_kw` 0
- Energiebilanz: 0 kWh bei Gleichgewicht, −166,67 kWh bei 1 MW Unterdeckung über 10 min, bei `demand_kw` 0 zählt die ganze Erzeugung als Plus
- Anhalten und Zurücksetzen: kein Tick bei `running` aus; `reset()` setzt Uhr, Bilanz, Frequenz, Leistung, Störung und Ladestand zurück, `unit_count` und Sollwert bleiben
- Zufall: nach `reset()` dieselben Werte, gleicher Seed → gleiche Werte, anderer Seed → andere Werte, unabhängig davon welche Anlagen laufen, eigener fester Wert → eigene Zahlenfolge. Einzeln erzeugte Test-Anlagen bekommen Seed 0, damit jeder Testlauf gleich ist.
- Ladefehler: fehlende Felder, unbekannter `type`, doppelte `id`, fehlende Assets, Punkt-Ordner

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
- Netzzusammenbruch und Spielende über eine Grenze der Energiebilanz (kWh) statt über 48–52 Hz, Grenzen je Schwierigkeitsgrad
- echte Verbraucher statt des Platzhalters `demand_kw`

**Vorerst wieder entfernt** (17.10.2026; der Code steht in der Git-History):
- Einflussgrößen `SimInputs` und Kennlinien `input.key`/`input.curve` (Sonne, Wind mit Sturmabschaltung, Wasser, Kühlwasser)
- Zufall über `variability` in der `plant.json` (`FastNoiseLite`, `EnergyMix.noise_seed`). Ersetzt durch einen einfachen Zufallswert mit `noise_level` (siehe Abschnitt 3). Den zentralen Seed gibt es seit 02.11.2026 wieder, jetzt als `EnergyMix.random_seed`.

**Noch offen (Team / Product Owner):**
1. **Konkrete Werte:** Leistungen, Baupunkte und `area_usage`.
2. **Rampenwerte:** Sie gelten pro Tick. Mit den kürzeren 3-min-Ticks fährt z. B. Kohle in Sim-Zeit schneller hoch als vorher, in Echtzeit gleich schnell.
3. **Export:** Im exportierten Build prüfen, dass alle `plant.json` gefunden werden. Gegebenenfalls `*.json` im Export-Filter „Nicht-Ressourcen-Dateien“ ergänzen.
