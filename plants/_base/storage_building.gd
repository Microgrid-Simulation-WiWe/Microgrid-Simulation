class_name StorageBuilding
extends PlantBuilding
## Gebäude eines Speichers: Lade-/Entladeleistung → Animation und Ton, Ladestand → Füllanzeige.

## Optionaler Node, der mit dem Ladestand in der Höhe skaliert wird.
@export var fill_indicator: Node3D


func _on_plant_state_changed(p_plant: PowerPlant) -> void:
	var storage := p_plant as StoragePlant
	var activity := 0.0
	if storage.installed_power_mw > 0.0:
		activity = absf(storage.actual_power_mw) / storage.installed_power_mw
	_show_activity(activity)
	if fill_indicator:
		fill_indicator.scale.y = maxf(storage.state_of_charge, 0.01)
