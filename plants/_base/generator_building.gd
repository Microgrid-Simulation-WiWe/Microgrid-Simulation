class_name GeneratorBuilding
extends PlantBuilding
## Gebäude eines Erzeugers: Aktivität → Animationstempo und Lautstärke.
## Die Aktivität kommt aus der Auslastung oder (anim_driver "wind") aus der Windgeschwindigkeit.


func _on_plant_state_changed(p_plant: PowerPlant) -> void:
	if definition.anim_driver == &"wind":
		var range := definition.wind_speed_range
		_show_activity(clampf(inverse_lerp(range.x, range.y, p_plant.wind_speed_ms), 0.0, 1.0))
		return
	var load_factor := 0.0
	if p_plant.installed_power_mw > 0.0:
		load_factor = p_plant.actual_power_mw / p_plant.installed_power_mw
	_show_activity(load_factor)
