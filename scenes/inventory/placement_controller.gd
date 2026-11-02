class_name PlacementController
extends Node
## Setzt Drops in die 3D-Welt um (Mausposition → Rasterfläche → prüfen → bauen)
## und verwaltet das per Klick ausgewählte Gebäude (z. B. zum Abreißen).

signal building_placed(building: PlantBuilding)
signal building_demolished(building: PlantBuilding)
signal placement_rejected(plant_id: StringName, reason: String)
## building = null heißt: nichts mehr ausgewählt.
signal selection_changed(building: PlantBuilding, screen_position: Vector2)

@export var energy_mix: EnergyMix
@export var drop_zone: PlacementDropZone
@export var camera: Camera3D
## Hier werden die Gebäude eingehängt (muss in der Welt der Kamera liegen).
@export var target: Node3D
## Spielfeld. Gebaut wird nur, wenn die ganze Fläche des Gebäudes darauf liegt. Leer = keine Grenze.
@export var field: MeshInstance3D
## Kantenlänge eines Rasterfelds in Welteinheiten. Die Felder pro Gebäude stehen in area_usage der plant.json.
@export var grid_size: float = 1.0

var _ground: Plane = Plane(Vector3.UP, 0.0)
var _occupancy: GridOccupancy = GridOccupancy.new()
var _ghost: PlacementGhost = PlacementGhost.new()
var _selected: PlantBuilding


func _ready() -> void:
	drop_zone.placement_check = _can_place_at
	drop_zone.plant_hovered.connect(_on_plant_hovered)
	drop_zone.hover_ended.connect(_ghost.hide)
	drop_zone.plant_dropped.connect(_on_plant_dropped)
	drop_zone.clicked.connect(_on_clicked)
	drop_zone.visibility_changed.connect(_select.bind(null, Vector2.ZERO))
	target.add_child.call_deferred(_ghost)


## Reißt das Gebäude ab: Felder frei, Einheit abziehen, aus der Welt entfernen.
func demolish(building: PlantBuilding) -> void:
	if building == _selected:
		_select(null, Vector2.ZERO)
	_occupancy.release(building)
	energy_mix.demolish(building)
	building_demolished.emit(building)
	building.queue_free()


func _on_plant_hovered(plant_id: StringName, screen_position: Vector2) -> void:
	if _selected:
		_select(null, Vector2.ZERO)
	var area: Variant = _area_at(plant_id, screen_position)
	if area == null:
		_ghost.hide()
		return
	_ghost.show_area(_area_center(area), Vector2(area.size) * grid_size, _mode_for(area))


func _can_place_at(plant_id: StringName, screen_position: Vector2) -> bool:
	var area: Variant = _area_at(plant_id, screen_position)
	return area != null and _check_area(area).is_empty()


func _on_plant_dropped(plant_id: StringName, drop_position: Vector2) -> void:
	var area: Variant = _area_at(plant_id, drop_position)
	if area == null:
		return  # Maus zeigt nicht auf den Boden → nichts bauen

	# Erst prüfen, dann bauen – sonst steigt unit_count trotz Ablehnung.
	var reason: String = _check_area(area)
	if not reason.is_empty():
		placement_rejected.emit(plant_id, reason)
		return

	var building: PlantBuilding = energy_mix.build(plant_id)
	if building == null:
		return
	_occupancy.occupy(area, building)
	building.position = target.to_local(_area_center(area))
	target.add_child(building)
	building_placed.emit(building)


## Klick auf ein Gebäude wählt es aus, Klick daneben hebt die Auswahl auf.
func _on_clicked(screen_position: Vector2) -> void:
	var building: PlantBuilding = null
	var hit: Variant = _mouse_to_ground(screen_position)
	if hit != null:
		var point: Vector3 = hit
		var cell: Vector2i = Vector2i(floori(point.x / grid_size), floori(point.z / grid_size))
		building = _occupancy.get_occupant(cell) as PlantBuilding
	_select(building, screen_position)


func _select(building: PlantBuilding, screen_position: Vector2) -> void:
	if building == null and _selected == null:
		return
	_selected = building
	if building:
		var area: Rect2i = _occupancy.get_area(building)
		_ghost.show_area(_area_center(area), Vector2(area.size) * grid_size, PlacementGhost.Mode.SELECTED)
	else:
		_ghost.hide()
	selection_changed.emit(building, screen_position)


func _mode_for(area: Rect2i) -> PlacementGhost.Mode:
	return PlacementGhost.Mode.VALID if _check_area(area).is_empty() else PlacementGhost.Mode.INVALID


## Leer, wenn gebaut werden darf, sonst der Grund.
func _check_area(area: Rect2i) -> String:
	if not _is_on_field(area):
		return "Außerhalb des Spielfelds"
	if not _occupancy.can_place(area):
		return "Feld ist belegt"
	return ""


## Rasterfläche des Gebäudes, mittig unter dem Mauszeiger. null, wenn die Maus nicht auf den Boden zeigt.
func _area_at(plant_id: StringName, screen_position: Vector2) -> Variant:
	var definition: PlantDefinition = PlantRegistry.get_by_id(plant_id)
	if definition == null:
		return null
	var hit: Variant = _mouse_to_ground(screen_position)
	if hit == null:
		return null
	var point: Vector3 = hit
	var size: Vector2i = definition.area_usage
	var origin: Vector2i = Vector2i(
		roundi(point.x / grid_size - size.x / 2.0),
		roundi(point.z / grid_size - size.y / 2.0)
	)
	return Rect2i(origin, size)


## Mittelpunkt der Fläche in Weltkoordinaten.
func _area_center(area: Rect2i) -> Vector3:
	var center: Vector2 = (Vector2(area.position) + Vector2(area.size) / 2.0) * grid_size
	return Vector3(center.x, 0.0, center.y)


## Liegen alle vier Ecken auf dem Spielfeld? Reicht, weil das Spielfeld konvex ist (auch gedreht).
func _is_on_field(area: Rect2i) -> bool:
	if field == null:
		return true
	var to_local: Transform3D = field.global_transform.affine_inverse()
	var bounds: AABB = field.get_aabb()
	var corners: Array[Vector2i] = [
		area.position, Vector2i(area.end.x, area.position.y), area.end, Vector2i(area.position.x, area.end.y)
	]
	for corner: Vector2i in corners:
		var local: Vector3 = to_local * (Vector3(corner.x, 0.0, corner.y) * grid_size)
		if local.x < bounds.position.x or local.x > bounds.end.x or local.z < bounds.position.z or local.z > bounds.end.z:
			return false
	return true


## Rechnet die Drop-Position in Viewport-Koordinaten um (SubViewport ist verkleinert)
## und schneidet den Kamerastrahl mit dem Boden. Liefert null, wenn nichts getroffen wird.
func _mouse_to_ground(drop_position: Vector2) -> Variant:
	var sub_viewport: Viewport = camera.get_viewport()
	var factor: Vector2 = sub_viewport.get_visible_rect().size / drop_zone.size
	var view_position: Vector2 = drop_position * factor
	var ray_origin: Vector3 = camera.project_ray_origin(view_position)
	var ray_direction: Vector3 = camera.project_ray_normal(view_position)
	return _ground.intersects_ray(ray_origin, ray_direction)
