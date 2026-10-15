# How-To: Neuen Anlagentyp anlegen

Ein Anlagentyp (z. B. Windrad, Biogas, Wasserstoffspeicher) ist **nur ein Ordner mit einer `plant.json`**. Dafür braucht es keinen Code und keine neue Szene. Das Spiel findet den Typ beim Start automatisch.

Als Beispiel legen wir eine **Biogasanlage** an.

## 1. Ordner anlegen

1. Im **Godot-Editor** im FileSystem-Dock auf `res://plants/` rechtsklicken → *Neu → Ordner*.
2. Als Name die `id` des Typs verwenden: klein, ohne Leerzeichen, mit `_`, z. B. `biogas`.

> Mit Dateien, die Godot importiert (`.png`, `.glb`, `.ogg` …), am besten **im Godot-Editor** arbeiten und nicht im Windows-Explorer kopieren. Sonst entstehen doppelte UIDs und kaputte Verweise.

## 2. `plant.json` anlegen

Die `plant.json` eines **ähnlichen** Typs in den neuen Ordner kopieren:

| Neuer Typ ist … | Vorlage |
|---|---|
| ein **Erzeuger**, abhängig vom Wetter | `solar/`, `wind/` oder `hydro/` |
| ein **Erzeuger**, frei steuerbar | `.gas/`, `coal/` oder `nuclear/` |
| ein **Speicher** | `battery/` oder `.pumped_hydro/` |

Für Biogas nehmen wir `.gas/plant.json`. Ordner mit `.` am Anfang zeigt der Godot-Editor nicht an, diese Datei also im Explorer oder in VS Code kopieren.

## 3. Werte anpassen

Die `plant.json` öffnen (Doppelklick im Godot-Editor) und mindestens diese Felder ändern:

```json
"id": "biogas",
"display_name": "Biogasanlage",
"type": "generator",
"sort_order": 9,
```

Danach Leistung, Mindestlast, Rampe, Baupunkte usw. setzen. Was jedes Feld bedeutet, steht in [`_base/plant_schema.md`](_base/plant_schema.md).

Häufige Fragen dazu:
- **Wetterabhängig?** Unter `input.key` die Einflussgröße eintragen (z. B. `"wind_speed"`) und die Kennlinie in `input.curve`.
- **Frei steuerbar?** `"key": ""` und `"curve": []`.
- **Träge wie ein Großkraftwerk?** Kleines `ramp_per_tick` (z. B. `1`–`5`) und eine Mindestlast (`min_load`).

## 4. Assets ablegen

Alle Dateien des Typs liegen in **seinem** Ordner. Bewährte Struktur:

```
plants/biogas/
├─ plant.json
├─ icon.png
├─ models/     biogas.glb
├─ textures/   (optional)
├─ sounds/     loop.ogg
└─ effects/    (optional, z. B. Rauch als Partikel-Szene)
```

Dann die Pfade in der `plant.json` eintragen. Sie sind **relativ zum Ordner**:

```json
"assets": {
	"icon": "icon.png",
	"model": "models/biogas.glb",
	"textures": { "albedo": "" },
	"animation": "run",
	"sounds": { "loop": "sounds/loop.ogg" },
	"effects": ["effects/smoke.tscn"],
	"scene": null
}
```

- Felder **ohne** Datei leer lassen (`""`). Dann zeigt das Spiel eine **graue Platzhalter-Box** in der Größe von `area_usage`.
- `animation` ist der Name der Animation im `.glb`. Sie läuft in Schleife, ihr Tempo folgt der Auslastung (Spanne in `visual.anim_speed`).
- `sounds.loop` ist der Dauerton der Anlage, seine Lautstärke folgt der Auslastung (`visual.volume_db`).
- Passen Größe oder Position des Modells nicht, korrigiert man das über `visual.scale` und `visual.offset`.
- `.png`, `.jpg`, `.glb`, `.ogg` und `.wav` landen über **Git LFS** im Repo (siehe `.gitattributes`). Dafür muss man nichts extra tun.

## 5. Prüfen

Die Befehle sind für **PowerShell**, ausgeführt im Projektordner (der Ordner mit der `project.godot`).

0. **Godot-Pfad festlegen** (einmal pro PowerShell-Fenster). Dafür den Pfad zur **Konsolenversion** von Godot (`Godot_v4.7.2-stable_win64_console.exe`) auf dem eigenen Rechner einsetzen:
   ```powershell
   $godot = "<Pfad zur Godot_v4.7.2-stable_win64_console.exe>"
   ```
   Das `&` in den folgenden Befehlen ist nötig, damit PowerShell den Inhalt der Variable als Programm startet.
1. **Importieren.** Godot registriert dabei neue Dateien und Klassen (`class_name`). Ohne diesen Schritt kennt das Testskript neue oder umbenannte Dateien nicht. Ausführen nach jeder neuen oder umbenannten Datei und vor dem ersten Testlauf:
   ```powershell
   & $godot --headless --path . --import
   ```
   Die Meldungen `Cannot get class 'GitPlugin'` und `Received a nullptr VCS extension instance` dabei sind harmlos. Das Git-Plugin wird ohne Editor-Oberfläche nicht geladen.
2. **Tests ausführen:**
   ```powershell
   & $godot --headless --path . --script res://plants/_tests/run_tests.gd
   ```
   Am Ende muss `ALLE TESTS OK` stehen.
3. **Warnungen** zur neuen `plant.json` im Output lesen:

| Meldung | Bedeutung | Lösung |
|---|---|---|
| `Feld '…' fehlt – Standardwert … wird verwendet` | Feld fehlt in der JSON | Feld ergänzen (oder bewusst `""` / `null` setzen) |
| `Asset '…' nicht gefunden – Platzhalter wird verwendet` | Pfad stimmt nicht oder Datei fehlt | Pfad relativ zum Typ-Ordner prüfen |
| `Unbekannte Einflussgröße '…'` | Tippfehler in `input.key` | Gültige Werte siehe `plant_schema.md` |
| `Unbekannter type '…' – Typ wird übersprungen` | `type` ist weder `generator` noch `storage` | korrigieren |
| `id '…' gibt es schon – Typ wird übersprungen` | Zwei Ordner mit derselben `id` | `id` ändern |
| `Kein gültiges JSON-Objekt` | Syntaxfehler (z. B. Komma zu viel) | JSON prüfen, z. B. mit einem JSON-Validator |

## 6. Im Spiel verwenden

Der `EnergyMix`-Node (`_base/energy_mix.gd`) legt beim Start automatisch für jeden Typ eine Logik-Instanz an. Der neue Typ ist also sofort dabei. Zugriff im Code:

```gdscript
var plant := energy_mix.get_plant(&"biogas")   # Steuerung: plant.setpoint, plant.enabled
var building := energy_mix.build(&"biogas")    # Bauphase: +1 Einheit, liefert das Gebäude
building.position = …
add_child(building)
```

Beim Spielen sind alle Werte im **Remote-Inspector** sichtbar und live änderbar (Szene-Dock → *Remote*). Das ist praktisch zum Ausprobieren, wird aber nicht gespeichert. Dauerhafte Änderungen gehören in die `plant.json`.

## Sonderfälle

- **Typ vorerst ausblenden:** Den Ordner mit `.` beginnen lassen (z. B. `gas` → `.gas`). Die Registry überspringt ihn dann. Der Godot-Editor zeigt Punkt-Ordner nicht an, umbenennen also im Explorer oder in VS Code.
- **Aufwendiges Gebäude** (mehrere Animationen, spezielle Effekte):
  1. Rechtsklick auf `_base/generator_building_base.tscn` (bzw. `storage_…`) → *Neue geerbte Szene*.
  2. Im Typ-Ordner speichern und in der JSON unter `assets.scene` eintragen.
- **Eigene Rechenlogik** für einen Typ ist noch nicht vorgesehen. Alle Erzeuger nutzen `GeneratorPlant`, alle Speicher `StoragePlant`. Bei Bedarf bitte im Team abstimmen (siehe `KONZEPT.md`, „Noch offen“).
