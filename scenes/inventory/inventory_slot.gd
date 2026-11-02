class_name InventorySlot
extends TextureRect
## Ein Feld der Inventarleiste. Zeigt das Icon (oder den Namen, falls es keins gibt)
## und startet Drag & Drop.

var definition: PlantDefinition


func setup(p_definition: PlantDefinition, slot_size: Vector2) -> void:
	definition = p_definition
	texture = definition.icon
	tooltip_text = "%s (Baupunkte: %d)" % [definition.display_name, definition.build_cost]
	custom_minimum_size = slot_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	if texture == null:
		var label: Label = _make_name_label()
		add_child(label)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)


## Godot ruft das automatisch auf, sobald man auf dem Slot die Maus zieht.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null:
		return null
	var preview: Control = _make_preview()
	preview.position = -custom_minimum_size / 2.0  # hängt mittig am Mauszeiger
	var holder: Control = Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return PlantDragData.new(definition.id)


func _make_preview() -> Control:
	if texture != null:
		var icon: TextureRect = TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = custom_minimum_size
		return icon
	var label: Label = _make_name_label()
	label.size = custom_minimum_size
	return label


func _make_name_label() -> Label:
	var label: Label = Label.new()
	label.text = definition.display_name
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
