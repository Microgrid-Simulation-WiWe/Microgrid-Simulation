class_name InventorySlot
extends TextureRect
## Ein Feld der Inventarleiste. Zeigt das Icon und startet Drag & Drop.

var definition: PlantDefinition


func setup(p_definition: PlantDefinition, slot_size: Vector2) -> void:
	definition = p_definition
	texture = definition.icon
	tooltip_text = "%s (Baupunkte: %d)" % [definition.display_name, definition.build_cost]
	custom_minimum_size = slot_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP


## Godot ruft das automatisch auf, sobald man auf dem Slot die Maus zieht.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition == null:
		return null
	var preview := TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = custom_minimum_size
	preview.position = -custom_minimum_size / 2.0  # Icon hängt mittig am Mauszeiger
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return PlantDragData.new(definition.id)
