class_name PlantCategory
extends Resource
## Gruppe von Anlagentypen für die Inventarleiste (z. B. „Erneuerbar“).
## Wird von PlantRegistry aus res://plants/categories.json erzeugt.

@export var id: StringName
@export var display_name: String
@export var sort_order: int
@export var icon: Texture2D


## Füllt die Kategorie aus einem Eintrag der categories.json. Pfade sind relativ zum Ordner der Datei.
func load_from_dict(data: Dictionary, folder: String) -> void:
	id = StringName(data.get("id", ""))
	display_name = data.get("display_name", String(id))
	sort_order = int(data.get("sort_order", 0))
	var icon_path: String = data.get("icon", "")
	if not icon_path.is_empty():
		var path := folder.path_join(icon_path)
		if ResourceLoader.exists(path):
			icon = load(path)
		else:
			push_warning("Kategorie '%s': Icon '%s' nicht gefunden." % [id, path])
