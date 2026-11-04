class_name PlacementDropZone
extends Control
## Unsichtbare Fläche über dem Spielfeld. Nimmt Drops und Klicks an und meldet sie per Signal.
## Gezogen wird entweder ein neuer Typ aus der Inventarleiste (PlantDragData)
## oder ein schon gebautes Gebäude (BuildingDragData).

signal plant_dropped(data: PlantDragData, screen_position: Vector2)
## Wird beim Ziehen über dem Spielfeld laufend gesendet (für die Vorschau).
signal plant_hovered(data: PlantDragData, screen_position: Vector2)
## Ziehen beendet oder Maus hat das Spielfeld während des Ziehens verlassen.
signal hover_ended
signal clicked(screen_position: Vector2)

## Maustaste zum Auswählen eines Gebäudes.
@export var select_button := MOUSE_BUTTON_LEFT

## Entscheidet, ob an einer Stelle gebaut werden darf: func(data, screen_position) -> bool.
## Setzt der PlacementController. Leer = überall erlaubt.
var placement_check: Callable
## Liefert das Datenpaket, wenn an der Stelle ein Gebäude zum Verschieben liegt:
## func(screen_position) -> PlantDragData oder null. Setzt der PlacementController. Leer = nichts verschiebbar.
var drag_source: Callable


func _get_drag_data(at_position: Vector2) -> Variant:
	return drag_source.call(at_position) if drag_source.is_valid() else null


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is PlantDragData:
		return false
	plant_hovered.emit(data, at_position)
	return not placement_check.is_valid() or placement_check.call(data, at_position)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	hover_ended.emit()
	plant_dropped.emit(data, at_position)


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
