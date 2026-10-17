class_name GeneratorDefinition
extends PlantDefinition
## Steckbrief eines Erzeugers (Wind, Solar, Wasser, Kohle, Gas, Atom …).

@export_group("Dynamik")
@export_range(0.0, 100.0, 1.0, "suffix:%") var min_load := 0.0


func create_plant() -> PowerPlant:
	return GeneratorPlant.new()


func _default_building_scene() -> PackedScene:
	return load("res://plants/_base/generator_building_base.tscn")


func load_from_dict(data: Dictionary, p_folder: String, source: String) -> void:
	super(data, p_folder, source)
	min_load = float(_value(data, "power.min_load", 0.0))
