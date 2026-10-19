class_name PlacementController
extends Node
## Setzt einen Drop in die 3D-Welt: Mausposition → Boden-Punkt → Gebäude bauen.

@export var energy_mix: EnergyMix
@export var drop_zone: PlacementDropZone
@export var camera: Camera3D
## Hier werden die Gebäude eingehängt (muss in der Welt der Kamera liegen).
@export var target: Node3D
@export var grid_size: float = 1.0

var _ground: Plane = Plane(Vector3.UP, 0.0)


func _ready() -> void:
	drop_zone.plant_dropped.connect(_on_plant_dropped)


func _on_plant_dropped(plant_id: StringName, screen_position: Vector2) -> void:
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var hit: Variant = _ground.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return  # Maus zeigt nicht auf den Boden → nichts bauen

	var building: PlantBuilding = energy_mix.build(plant_id)
	if building == null:
		return
	var point: Vector3 = hit
	building.position = point.snapped(Vector3(grid_size, grid_size, grid_size))
	target.add_child(building)
