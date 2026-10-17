extends Button
## Test-Knopf: baut bei jedem Klick ein Windrad und stellt es in die Welt.
## wird später entfernt -> Objtekte werden durch "Inventarbar" / Code erzeugt

@export var energy_mix: EnergyMix
## Hier werden die Gebäude eingehängt (muss in der Welt der Kamera liegen).
@export var target: Node3D

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	var building := energy_mix.build(&"wind")
	if building == null:
		return
	building.position = Vector3(randi_range(-20,20), 0.0, randi_range(-20,20))
	target.add_child(building)
