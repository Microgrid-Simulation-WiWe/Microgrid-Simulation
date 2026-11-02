class_name PlacementController
extends Node
## Setzt einen Drop in die 3D-Welt: Mausposition → Rasterfläche → prüfen → bauen.

signal building_placed(building: PlantBuilding)
signal placement_rejected(plant_id: StringName, reason: String)

@export var energy_mix: EnergyMix
@export var drop_zone: PlacementDropZone
@export var camera: Camera3D
## Hier werden die Gebäude eingehängt (muss in der Welt der Kamera liegen).
@export var target: Node3D
@export var grid_size: float = 1.0

var _ground: Plane = Plane(Vector3.UP, 0.0)
var _occupancy: GridOccupancy = GridOccupancy.new()


func _ready() -> void:
	drop_zone.plant_dropped.connect(_on_plant_dropped)


func _on_plant_dropped(plant_id: StringName, drop_position: Vector2) -> void:
	var definition: PlantDefinition = PlantRegistry.get_by_id(plant_id)
	if definition == null:
		return

	var hit: Variant = _mouse_to_ground(drop_position)
	if hit == null:
		return  # Maus zeigt nicht auf den Boden → nichts bauen
	var point: Vector3 = hit

	# Fläche des Gebäudes um den Mauszeiger zentrieren und aufs Raster legen.
	var size: Vector2i = definition.area_usage
	var origin: Vector2i = Vector2i(
		roundi(point.x / grid_size - size.x / 2.0),
		roundi(point.z / grid_size - size.y / 2.0)
	)

	# Erst prüfen, dann bauen – sonst steigt unit_count trotz Ablehnung.
	if not _occupancy.can_place(origin, size):
		placement_rejected.emit(plant_id, "Feld ist belegt")
		return

	var building: PlantBuilding = energy_mix.build(plant_id)
	if building == null:
		return
	_occupancy.occupy(origin, size)
	building.position = Vector3(
		(origin.x + size.x / 2.0) * grid_size,
		0.0,
		(origin.y + size.y / 2.0) * grid_size
	)
	target.add_child(building)
	building_placed.emit(building)


## Rechnet die Drop-Position in Viewport-Koordinaten um (SubViewport ist verkleinert)
## und schneidet den Kamerastrahl mit dem Boden. Liefert null, wenn nichts getroffen wird.
func _mouse_to_ground(drop_position: Vector2) -> Variant:
	var sub_viewport: Viewport = camera.get_viewport()
	var factor: Vector2 = sub_viewport.get_visible_rect().size / drop_zone.size
	var view_position: Vector2 = drop_position * factor
	var ray_origin: Vector3 = camera.project_ray_origin(view_position)
	var ray_direction: Vector3 = camera.project_ray_normal(view_position)
	return _ground.intersects_ray(ray_origin, ray_direction)
