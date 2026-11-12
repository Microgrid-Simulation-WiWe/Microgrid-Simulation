class_name ConfirmPanel
extends CenteredPanel
## Rückfrage mit Ja / Nein in der Bildschirmmitte, im Stil der Auswertung. Standardmäßig modal.
## Aufruf: ask(title, message), die Antwort kommt über das Signal answered, z. B.
##   confirm_panel.ask("Titel", "Frage")
##   if await confirm_panel.answered: ...

## true = Ja. Wird das Popup ohne Antwort ausgeblendet (z. B. durch ein anderes Popup), zählt das als Nein.
signal answered(confirmed: bool)

@export var confirm_text := "Ja"
@export var cancel_text := "Nein"

var _waiting := false


func _init() -> void:
	modal = true


func ask(title: String, message: String) -> void:
	clear()
	add_title(title)
	add_text(message, true)
	var buttons := add_buttons([confirm_text, cancel_text])
	buttons[0].pressed.connect(_answer.bind(true))
	buttons[1].pressed.connect(_answer.bind(false))
	_waiting = true
	popup()


func _answer(confirmed: bool) -> void:
	if not _waiting:
		return
	_waiting = false
	hide()
	answered.emit(confirmed)


func _on_visibility_changed() -> void:
	super()
	if not visible:
		_answer(false)
