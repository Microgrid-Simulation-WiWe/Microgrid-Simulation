class_name PlacementDropZone
extends Control
## Unsichtbare Fläche über dem Spielfeld. Nimmt Drops und Klicks an und meldet sie per Signal.

signal plant_dropped(plant_id: StringName, screen_position: Vector2)
## Wird beim Ziehen über dem Spielfeld laufend gesendet (für die Vorschau).
signal plant_hovered(plant_id: StringName, screen_position: Vector2)
## Ziehen beendet oder Maus hat das Spielfeld während des Ziehens verlassen.
signal hover_ended
signal clicked(screen_position: Vector2)

## Maustaste zum Auswählen eines Gebäudes.
@export var select_button := MOUSE_BUTTON_LEFT

## Entscheidet, ob an einer Stelle gebaut werden darf: func(plant_id, screen_position) -> bool.
## Setzt der PlacementController. Leer = überall erlaubt.
var placement_check: Callable


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is PlantDragData:
		return false
	var drag_data := data as PlantDragData
	plant_hovered.emit(drag_data.plant_id, at_position)
	return not placement_check.is_valid() or placement_check.call(drag_data.plant_id, at_position)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var drag_data := data as PlantDragData
	hover_ended.emit()
	plant_dropped.emit(drag_data.plant_id, at_position)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index == select_button:
		clicked.emit(button.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		hover_ended.emit()
	elif what == NOTIFICATION_MOUSE_EXIT and get_viewport().gui_is_dragging():
		hover_ended.emit()
