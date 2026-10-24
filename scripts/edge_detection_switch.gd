extends MeshInstance3D
## Tauscht den Edge-Detection-Shader gegen die Compatibility-Variante, wenn das Spiel mit dem
## Compatibility-Renderer läuft (immer beim Web-Export). Die Shader-Parameter bleiben erhalten.

@export var compatibility_shader: Shader


func _ready() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility" or compatibility_shader == null:
		return
	var material := get_surface_override_material(0).duplicate() as ShaderMaterial
	material.shader = compatibility_shader
	set_surface_override_material(0, material)
