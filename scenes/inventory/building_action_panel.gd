class_name BuildingActionPanel
extends PanelContainer
## Kleines Menü neben dem ausgewählten Gebäude. Bietet den Abriss an.

@export var placement: PlacementController
@export var demolish_text := "Kraftwerk abreißen"
## Abstand zum Klickpunkt.
@export var click_offset := Vector2(12.0, 12.0)

var _building: PlantBuilding


func _ready() -> void:
	var button := Button.new()
	button.text = demolish_text
	button.pressed.connect(_on_demolish_pressed)
	add_child(button)
	placement.selection_changed.connect(_on_selection_changed)
	hide()


func _on_selection_changed(building: PlantBuilding, screen_position: Vector2) -> void:
	_building = building
	if building == null:
		hide()
		return
	tooltip_text = building.definition.display_name
	show()
	reset_size()
	# Neben dem Klick, aber nicht über den Bildschirmrand hinaus.
	var limit: Vector2 = get_viewport_rect().size - size
	global_position = (screen_position + click_offset).clamp(Vector2.ZERO, limit)


func _on_demolish_pressed() -> void:
	if _building:
		placement.demolish(_building)
