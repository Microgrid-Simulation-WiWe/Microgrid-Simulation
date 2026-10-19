class_name InventoryBar
extends PanelContainer
## Inventarleiste unten links. Legt pro Anlagentyp der PlantRegistry einen Slot an.

@export var slot_size: Vector2 = Vector2(56.0, 56.0)
@export var screen_margin: int = 16

var _slots: HBoxContainer


func _ready() -> void:
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	add_child(_slots)
	refresh()


## Baut alle Slots neu auf. Kann man jederzeit erneut aufrufen.
func refresh() -> void:
	for child: Node in _slots.get_children():
		child.queue_free()
	for definition: PlantDefinition in PlantRegistry.get_all():
		var slot := InventorySlot.new()
		slot.setup(definition, slot_size)
		_slots.add_child(slot)
	# Unten links verankern, die Leiste wächst nach oben/rechts mit dem Inhalt.
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, screen_margin)
