@abstract
class_name PlantBuilding
extends Node3D
## Darstellung eines gebauten Gebäudes. Rechnet nichts, liest nur den Zustand seiner Anlage
## und baut sich aus den Assets der plant.json auf. setup() vor add_child() aufrufen.

var definition: PlantDefinition
var plant: PowerPlant
var _animation_player: AnimationPlayer


func setup(p_definition: PlantDefinition, p_plant: PowerPlant) -> void:
	definition = p_definition
	plant = p_plant
	_build()
	plant.state_changed.connect(_on_plant_state_changed)


## Wird nach jedem Tick der Anlage aufgerufen.
@abstract func _on_plant_state_changed(p_plant: PowerPlant) -> void


func _build() -> void:
	var model_root: Node3D = $Model
	model_root.add_child(definition.model.instantiate() if definition.model else _create_placeholder())
	model_root.scale = Vector3.ONE * definition.visual_scale
	model_root.position = definition.visual_offset

	for effect in definition.effects:
		$Effects.add_child(effect.instantiate())

	var sound: AudioStream = definition.sounds.get("loop")
	if sound:
		$AudioStreamPlayer3D.stream = sound
		$AudioStreamPlayer3D.autoplay = true

	# Animation aus dem Modell (.glb) bevorzugen, sonst den eigenen AnimationPlayer nutzen.
	var players := model_root.find_children("*", "AnimationPlayer", true, false)
	_animation_player = players[0] if not players.is_empty() else $AnimationPlayer
	if _animation_player.has_animation(definition.animation):
		_animation_player.play(definition.animation)


## Zeigt die Aktivität (0..1) über Animationstempo und Lautstärke.
func _show_activity(activity: float) -> void:
	var idle := is_zero_approx(activity)
	_animation_player.speed_scale = 0.0 if idle else lerpf(definition.anim_speed.x, definition.anim_speed.y, activity)
	$AudioStreamPlayer3D.stream_paused = idle
	$AudioStreamPlayer3D.volume_db = lerpf(definition.volume_db.x, definition.volume_db.y, activity)


## Graue Box in der Größe von area_usage, solange es kein Modell gibt.
func _create_placeholder() -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3(definition.area_usage.x, 1.0, definition.area_usage.y)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	mesh_instance.position.y = 0.5
	return mesh_instance
