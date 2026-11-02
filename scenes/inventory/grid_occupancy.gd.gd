class_name GridOccupancy
extends RefCounted
## Merkt sich, welche Rasterfelder belegt sind. Kennt weder Szene noch UI.

var _occupied: Dictionary[Vector2i, bool] = {}


## true, wenn alle Felder der Fläche frei sind.
func can_place(origin: Vector2i, size: Vector2i) -> bool:
	for cell: Vector2i in _cells(origin, size):
		if _occupied.has(cell):
			return false
	return true


func occupy(origin: Vector2i, size: Vector2i) -> void:
	for cell: Vector2i in _cells(origin, size):
		_occupied[cell] = true


func _cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in size.x:
		for y: int in size.y:
			cells.append(origin + Vector2i(x, y))
	return cells
