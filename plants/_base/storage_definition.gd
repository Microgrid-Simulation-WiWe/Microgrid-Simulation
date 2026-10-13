class_name StorageDefinition
extends PlantDefinition
## Steckbrief eines Speichers (Batterie, Pumpspeicher …).

@export_group("Speicher")
@export_range(0.0, 10000.0, 0.1, "or_greater", "suffix:MWh") var unit_capacity_mwh := 0.0
@export_range(0.01, 1.0, 0.01) var charge_efficiency := 1.0
@export_range(0.01, 1.0, 0.01) var discharge_efficiency := 1.0
@export_range(0.0, 1.0, 0.01) var initial_soc := 0.5


func create_plant() -> PowerPlant:
	return StoragePlant.new()


func _default_building_scene() -> PackedScene:
	return load("res://plants/_base/storage_building_base.tscn")


func load_from_dict(data: Dictionary, p_folder: String, source: String) -> void:
	super(data, p_folder, source)
	unit_capacity_mwh = float(_value(data, "storage.unit_capacity_mwh", 0.0))
	charge_efficiency = clampf(float(_value(data, "storage.charge_efficiency", 1.0)), 0.01, 1.0)
	discharge_efficiency = clampf(float(_value(data, "storage.discharge_efficiency", 1.0)), 0.01, 1.0)
	initial_soc = clampf(float(_value(data, "storage.initial_soc", 0.5)), 0.0, 1.0)
