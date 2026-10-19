class_name PlantDragData
extends RefCounted
## Datenpaket, das beim Ziehen aus der Inventarleiste mitgegeben wird.

var plant_id: StringName


func _init(p_plant_id: StringName) -> void:
	plant_id = p_plant_id
