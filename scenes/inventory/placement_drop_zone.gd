class_name PlacementDropZone
extends Control
## Unsichtbare Fläche über dem Spielfeld. Nimmt Drops an und meldet sie per Signal.

signal plant_dropped(plant_id: StringName, screen_position: Vector2)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is PlantDragData


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drag_data := data as PlantDragData
	plant_dropped.emit(drag_data.plant_id, at_position)
