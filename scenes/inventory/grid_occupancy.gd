class_name GridOccupancy
extends RefCounted
## Merkt sich, welche Rasterfelder von wem belegt sind. Kennt weder Szene noch UI.

var _occupants: Dictionary[Vector2i, Object] = {}
var _areas: Dictionary[Object, Rect2i] = {}


## true, wenn alle Felder der Fläche frei sind. Felder von ignore zählen als frei (beim Verschieben).
func can_place(area: Rect2i, ignore: Object = null) -> bool:
	for cell: Vector2i in _cells(area):
		if _occupants.has(cell) and _occupants[cell] != ignore:
			return false
	return true


func occupy(area: Rect2i, occupant: Object) -> void:
	_areas[occupant] = area
	for cell: Vector2i in _cells(area):
		_occupants[cell] = occupant


## Gibt alle Felder des Belegers wieder frei.
func release(occupant: Object) -> void:
	if not _areas.has(occupant):
		return
	for cell: Vector2i in _cells(_areas[occupant]):
		_occupants.erase(cell)
	_areas.erase(occupant)


## Fläche, die der Beleger einnimmt.
func get_area(occupant: Object) -> Rect2i:
	return _areas.get(occupant, Rect2i())


## Alle Beleger, jeder einmal.
func get_occupants() -> Array[Object]:
	var occupants: Array[Object] = []
	occupants.assign(_areas.keys())
	return occupants


## Wer das Feld belegt, oder null.
func get_occupant(cell: Vector2i) -> Object:
	return _occupants.get(cell)


func _cells(area: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x: int in area.size.x:
		for y: int in area.size.y:
			cells.append(area.position + Vector2i(x, y))
	return cells
