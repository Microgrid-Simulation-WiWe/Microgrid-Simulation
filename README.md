# Microgrid-Simulation

Planspiel zu einem lokalen Stromnetz (Microgrid), entwickelt mit Godot 4.7 (3D, GDScript) im Capstone-Projekt an der DHBW.

Der Spieler baut einen Mix aus Erzeugern und Speichern und regelt sie während einer Runde von Hand. Ziel ist, dass Erzeugung und Verbrauch zusammenpassen.

## Spielablauf

1. **Szenario wählen** (Dropdown oben in der Mitte). Das geht in jeder Bauphase. Steht schon etwas, fragt das Spiel nach: Bei „Ja“ werden alle gebauten Kraftwerke abgerissen, und das neue Szenario startet leer.
2. **Bauphase:** Anlagen aus der Inventarleiste aufs Spielfeld ziehen. Gebaute Anlagen kann man verschieben oder per Klick abreißen. Sie belegen Rasterfelder und dürfen sich nicht überlappen.
3. **„Simulation starten“:** Eine Runde ist ein simulierter Tag und dauert etwa 8 Minuten. Der Spieler stellt die Sollwerte der Anlagen ein und behält die Leistungsbilanz im Blick (grün / gelb / rot). Während der Runde wird nicht gebaut.
4. **Auswertung:** Nach der Runde oder nach einem Abbruch erscheinen der Netzzustand (stabil, zeitweise rot mit der längsten roten Phase, oder „zusammengebrochen nach x h“, wenn die Leistungsbilanz zu lange am Stück rot war), Netzstabilität, Unterdeckung und Überschuss, CO₂, Kosten und Atommüll, gesamt und je Erzeuger. Danach geht es zurück in die Bauphase.

## Starten

- Den Ordner in **Godot 4.7** öffnen und das Projekt starten (F5). Die Hauptszene ist `scenes/level.tscn`.
- Gerendert wird mit dem Compatibility-Renderer (`gl_compatibility`).

## Ordner

| Ordner | Inhalt |
|---|---|
| `plants/` | Anlagentypen: eine `plant.json` pro Typ, Basisklassen in `_base/`, Tests in `_tests/` |
| `scenarios/` | Szenarien: eine JSON-Datei pro Szenario, Basisklassen in `_base/`, Tests in `_tests/` |
| `scenes/` | Level-Szene und UI: Spielablauf (`game_flow/`), Inventarleiste und Bauen (`inventory/`), Auswertung (`round_summary/`), Szenario-Auswahl (`scenario/`), Popups (`ui/`) |
| `scripts/` | Anzeigen (Leistung, Leistungsbilanz), Gras, Kantenerkennung |
| `assets/` | Modelle, Materialien, Shader, Sprites, Animationen |
| `docs/` | Klassendiagramm (`klassendiagramm.svg`) |

## Dokumentation

- [`plants/KONZEPT.md`](plants/KONZEPT.md): Konzept der Anlagentypen, Simulation, Rundenablauf, Zufall und Seed, Stand der Umsetzung
- [`plants/HOW_TO.md`](plants/HOW_TO.md): einen neuen Anlagentyp anlegen
- [`plants/_base/plant_schema.md`](plants/_base/plant_schema.md): alle Felder der `plant.json` und `categories.json`
- [`scenarios/KONZEPT.md`](scenarios/KONZEPT.md): Konzept der Szenarien und ein neues Szenario anlegen
- [`scenarios/_base/scenario_schema.md`](scenarios/_base/scenario_schema.md): alle Felder einer Szenario-JSON
- [`docs/klassendiagramm.svg`](docs/klassendiagramm.svg): Klassendiagramm

Die Planung des Teams (Spielablauf, Sprint Reviews, Kanban) liegt in Notion.

## Tests

Im Projektordner, mit der Konsolen-Version von Godot:

```bash
godot --headless --path . --script res://plants/_tests/run_tests.gd
godot --headless --path . --script res://scenarios/_tests/run_tests.gd
```

Am Ende steht „ALLE TESTS OK“ oder die Zahl der fehlgeschlagenen Tests. Warnungen und Fehler beim Laden der Fixtures sind gewollt. Wurden neue Skripte mit `class_name` angelegt, vorher einmal `godot --headless --path . --import` ausführen.

## Lizenz

CC0 1.0 Universal, siehe [`LICENSE`](LICENSE).
