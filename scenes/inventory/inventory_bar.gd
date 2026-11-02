class_name InventoryBar
extends PanelContainer
## Inventarleiste unten links. Oben ein Reiter pro Kategorie der PlantRegistry,
## darunter die Slots der Anlagentypen des gewählten Reiters.

@export var slot_size: Vector2 = Vector2(56.0, 56.0)
@export var screen_margin: int = 16
## Reiter für Typen ohne oder mit unbekannter Kategorie.
@export var other_tab_name := "Sonstige"

var _tabs: HBoxContainer
var _slots: HBoxContainer
var _tab_group := ButtonGroup.new()
var _categories: Array[PlantCategory] = []
## Sammelt die Typen ohne gültige Kategorie.
var _other := PlantCategory.new()
var _selected := 0


func _ready() -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	add_child(rows)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	rows.add_child(_tabs)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 8)
	rows.add_child(_slots)
	refresh()


## Baut Reiter und Slots neu auf. Kann man jederzeit erneut aufrufen.
func refresh() -> void:
	_other.display_name = other_tab_name
	_categories.clear()
	for category: PlantCategory in PlantRegistry.get_categories() + [_other]:
		if not _definitions_of(category).is_empty():
			_categories.append(category)
	_clear(_tabs)
	for index: int in _categories.size():
		_tabs.add_child(_make_tab(index))
	_tabs.visible = _categories.size() > 1  # Nur eine Gruppe → Reiter überflüssig
	_select(clampi(_selected, 0, maxi(_categories.size() - 1, 0)))


func _definitions_of(category: PlantCategory) -> Array[PlantDefinition]:
	if category == _other:
		return PlantRegistry.get_uncategorized()
	return PlantRegistry.get_in_category(category.id)


func _make_tab(index: int) -> Button:
	var tab := Button.new()
	tab.text = _categories[index].display_name
	tab.icon = _categories[index].icon
	tab.toggle_mode = true
	tab.button_group = _tab_group
	tab.focus_mode = Control.FOCUS_NONE
	tab.pressed.connect(_select.bind(index))
	return tab


func _select(index: int) -> void:
	_selected = index
	_clear(_slots)
	if _categories.is_empty():
		return
	(_tabs.get_child(index) as Button).set_pressed_no_signal(true)
	for definition: PlantDefinition in _definitions_of(_categories[index]):
		var slot := InventorySlot.new()
		slot.setup(definition, slot_size)
		_slots.add_child(slot)
	# Unten links verankern, die Leiste wächst nach oben/rechts mit dem Inhalt.
	reset_size()
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, screen_margin)


func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
