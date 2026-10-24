@tool
extends MultiMeshInstance3D
## Verteilt die Instanzen der MultiMesh zufällig über die Fläche von `ground`.
## Läuft auch im Editor, damit man das Ergebnis direkt sieht.

## Fläche, auf der das Gras wachsen soll (MeshInstance3D mit PlaneMesh o. ä.).
@export var ground: MeshInstance3D:
	set(value):
		ground = value
		_scatter()
@export_range(0, 100000, 1) var count := 5000:
	set(value):
		count = value
		_scatter()
## Zufällige Skalierung pro Büschel (min, max).
@export var scale_range := Vector2(0.6, 1.2):
	set(value):
		scale_range = value
		_scatter()
@export var random_seed := 1:
	set(value):
		random_seed = value
		_scatter()


func _ready() -> void:
	_scatter()


func _scatter() -> void:
	if not is_inside_tree() or ground == null or ground.mesh == null or multimesh == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var aabb := ground.mesh.get_aabb()
	# Von der lokalen Fläche des Bodens in den Raum dieses Nodes umrechnen.
	var to_local := global_transform.affine_inverse() * ground.global_transform

	multimesh.instance_count = 0 # transform_format lässt sich nur bei 0 Instanzen ändern
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = count
	for i in count:
		var local_pos := Vector3(
			rng.randf_range(aabb.position.x, aabb.end.x),
			aabb.end.y,
			rng.randf_range(aabb.position.z, aabb.end.z))
		var basis := Basis.from_scale(Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y))
		multimesh.set_instance_transform(i, Transform3D(basis, to_local * local_pos))
