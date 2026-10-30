class_name GameFlow
extends Node
## Trennt Bauen und Simulation. In der Bauphase steht die Simulation still und nur das Inventar ist sichtbar.
## Eine Runde ist ein simulierter Tag. Danach oder bei Abbruch geht es zurück in die Bauphase,
## die nächste Runde beginnt von vorne (Gebautes und Sollwerte bleiben).

## Nach jeder Runde, bevor die Simulation zurückgesetzt wird. completed = false heißt abgebrochen.
signal round_finished(completed: bool)

enum Phase { BUILD, SIMULATION }

@export var energy_mix: EnergyMix
## Schaltet um: „Simulation starten“ bzw. „Simulation beenden“.
@export var phase_button: Button
## Nur in der Bauphase sichtbar.
@export var build_ui: Array[Control] = []
## Nur während der Simulation sichtbar.
@export var simulation_ui: Array[Control] = []
## Simulierte Dauer einer Runde.
@export_range(1.0, 168.0, 1.0, "suffix:h") var round_hours := 24.0

var phase := Phase.BUILD


func _ready() -> void:
	phase_button.pressed.connect(_on_phase_button_pressed)
	_enter_build()


func _process(_delta: float) -> void:
	if phase == Phase.SIMULATION and energy_mix.tick_count >= roundi(round_hours / energy_mix.tick_hours):
		end_round(true)


func start_simulation() -> void:
	phase = Phase.SIMULATION
	energy_mix.running = true
	_update_ui()


## Beendet die Runde und kehrt in die Bauphase zurück.
func end_round(completed: bool) -> void:
	energy_mix.running = false
	round_finished.emit(completed)
	_enter_build()


func _enter_build() -> void:
	phase = Phase.BUILD
	energy_mix.running = false
	energy_mix.reset()
	_update_ui()


func _update_ui() -> void:
	var building := phase == Phase.BUILD
	for control in build_ui:
		control.visible = building
	for control in simulation_ui:
		control.visible = not building
	phase_button.text = "Simulation starten" if building else "Simulation beenden"


func _on_phase_button_pressed() -> void:
	if phase == Phase.BUILD:
		start_simulation()
	else:
		end_round(false)
