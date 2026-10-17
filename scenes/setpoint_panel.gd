extends PanelContainer
## Kasten am rechten Rand (Mitte): je Anlagentyp ein Schieberegler für den Sollwert.

@export var energy_mix: EnergyMix


func _ready() -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)

	var title := Label.new()
	title.text = "Sollwerte"
	rows.add_child(title)

	for definition in PlantRegistry.get_all():
		var plant := energy_mix.get_plant(definition.id)
		if plant != null:
			rows.add_child(_make_row(plant))


func _make_row(plant: PowerPlant) -> Control:
	var row := VBoxContainer.new()

	var header := HBoxContainer.new()
	row.add_child(header)
	var name_label := Label.new()
	name_label.text = plant.definition.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := Label.new()
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = -100.0 if plant is StoragePlant else 0.0  # Speicher: laden (−) .. entladen (+)
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(180, 0)
	slider.value = plant.setpoint
	row.add_child(slider)

	value_label.text = "%d %%" % slider.value
	slider.value_changed.connect(func(value: float) -> void:
		plant.setpoint = value
		value_label.text = "%d %%" % value
	)
	return row
