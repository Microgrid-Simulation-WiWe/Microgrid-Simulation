class_name GeneratorBuilding
extends PlantBuilding
## Gebäude eines Erzeugers: Auslastung → Animationstempo und Lautstärke.


func _on_plant_state_changed(p_plant: PowerPlant) -> void:
	var load_factor := 0.0
	if p_plant.installed_power_mw > 0.0:
		load_factor = p_plant.actual_power_mw / p_plant.installed_power_mw
	_show_activity(load_factor)
