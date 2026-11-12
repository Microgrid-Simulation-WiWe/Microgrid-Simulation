@abstract
class_name CenteredPanel
extends PanelContainer
## Basis für Popups in der Bildschirmmitte, z. B. die Auswertung nach der Runde oder eine Rückfrage.
## Baut Rahmen und Innenabstand auf und stellt Bausteine für den Inhalt bereit
## (clear, add_title, add_text, add_buttons). Unterklassen füllen den Inhalt und rufen dann popup() auf.
## Es ist immer nur ein Popup sichtbar: popup() blendet die anderen aus.

const GROUP := &"centered_panels"

@export var title_font_size := 24
## Innenabstand zum Rand der Box.
@export var padding := 16
## Abstand zwischen den Zeilen des Inhalts.
@export var separation := 12
## Breite, ab der lange Texte (add_text mit wrap) umbrechen.
@export var text_width := 420.0
## Modal: Solange das Popup offen ist, liegt eine Abdeckung über dem Rest der Oberfläche
## und fängt alle Klicks ab (nicht bauen, keine Runde starten).
@export var modal := false
@export var modal_color := Color(0.0, 0.0, 0.0, 0.4)

var _content: VBoxContainer
var _blocker: ColorRect


func _ready() -> void:
	add_to_group(GROUP)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", separation)
	margin.add_child(_content)
	if modal:
		# Erst wenn der Elternknoten fertig aufgebaut ist, darf ein Geschwisterknoten dazukommen.
		_add_blocker.call_deferred()
	visibility_changed.connect(_on_visibility_changed)
	hide()


## Zeigt das Popup mittig an und blendet die anderen Popups aus.
func popup() -> void:
	for panel in get_tree().get_nodes_in_group(GROUP):
		if panel != self:
			(panel as CanvasItem).hide()
	show()
	# Erst im nächsten Frame kennt der Container seine neue Mindestgröße.
	set_anchors_and_offsets_preset.call_deferred(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## Entfernt den bisherigen Inhalt.
func clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func add_title(text: String) -> Label:
	var label := add_text(text)
	label.add_theme_font_size_override("font_size", title_font_size)
	return label


## Textzeile. wrap = true bricht lange Texte bei text_width um.
func add_text(text: String, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = text_width
	_content.add_child(label)
	return label


## Knopfleiste mittig unter dem Inhalt, ein Knopf je Text (in dieser Reihenfolge).
func add_buttons(texts: PackedStringArray) -> Array[Button]:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", separation)
	_content.add_child(row)
	var buttons: Array[Button] = []
	for text in texts:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size.x = 80.0
		row.add_child(button)
		buttons.append(button)
	return buttons


## Abdeckung direkt vor dem Popup einhängen: Sie liegt damit über allem, was davor im Szenenbaum steht.
func _add_blocker() -> void:
	_blocker = ColorRect.new()
	_blocker.color = modal_color
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.visible = visible
	get_parent().add_child(_blocker)
	get_parent().move_child(_blocker, get_index())
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _on_visibility_changed() -> void:
	if _blocker != null:
		_blocker.visible = visible
