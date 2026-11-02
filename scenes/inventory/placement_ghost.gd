class_name PlacementGhost
extends MeshInstance3D
## Halbtransparente Fläche auf dem Boden: zeigt beim Ziehen, ob dort Platz ist,
## und markiert das ausgewählte Gebäude.

enum Mode { VALID, INVALID, SELECTED }

@export var valid_color := Color(0.6, 1.0, 0.5, 0.7)
@export var invalid_color := Color(1.0, 0.15, 0.15, 0.7)
@export var selected_color := Color(1.0, 1.0, 1.0, 0.6)
@export var height := 0.05

var _box := BoxMesh.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Immer sichtbar, auch durch Gras und Gebäude hindurch.
	_material.no_depth_test = true
	_material.render_priority = Material.RENDER_PRIORITY_MAX
	_box.material = _material
	mesh = _box
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()


## center in Weltkoordinaten, size in Welteinheiten (x, z).
func show_area(center: Vector3, size: Vector2, mode: Mode) -> void:
	_box.size = Vector3(size.x, height, size.y)
	global_position = center + Vector3.UP * height / 2.0
	_material.albedo_color = _color_for(mode)
	show()


func _color_for(mode: Mode) -> Color:
	match mode:
		Mode.INVALID:
			return invalid_color
		Mode.SELECTED:
			return selected_color
	return valid_color
