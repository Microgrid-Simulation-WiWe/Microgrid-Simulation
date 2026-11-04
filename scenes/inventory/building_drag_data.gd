class_name BuildingDragData
extends PlantDragData
## Datenpaket, wenn ein schon gebautes Gebäude auf dem Spielfeld verschoben wird.

var building: PlantBuilding


func _init(p_building: PlantBuilding) -> void:
	super(p_building.definition.id)
	building = p_building
