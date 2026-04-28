extends RefCounted
class_name DragDropValidator

# Responsabilidad:
# - Validar `content` de `drag_drop`.
# - Detectar targets repetidos.
# - Detectar items repetidos.
# - Detectar `correct_target` inexistente.
# - Detectar si no hay items correctos.
# No hace:
# - No renderiza UI.
# - No abre escenas.
# - No modifica estado del mapa.


static func validate_content(content: Dictionary) -> String:
	var target_ids: Array[String] = []
	var raw_targets: Array = content.get("targets", [])
	for raw_target in raw_targets:
		var target: Dictionary = raw_target as Dictionary
		var target_id: String = str(target.get("id", "")).strip_edges()
		if target_ids.has(target_id):
			return "DragDrop: hay targets repetidos (%s)." % target_id
		target_ids.append(target_id)

	var has_correct_items: bool = false
	var seen_item_ids: Array[String] = []
	var raw_items: Array = content.get("items", [])
	for raw_item in raw_items:
		var item: Dictionary = raw_item as Dictionary
		var item_id: String = str(item.get("id", "")).strip_edges()
		if seen_item_ids.has(item_id):
			return "DragDrop: hay items repetidos (%s)." % item_id
		seen_item_ids.append(item_id)

		var correct_target: String = str(item.get("correct_target", "")).strip_edges()
		if correct_target.is_empty():
			continue
		has_correct_items = true
		if not target_ids.has(correct_target):
			return "DragDrop: el item %s apunta a un target inexistente (%s)." % [item_id, correct_target]

	if not has_correct_items:
		return "DragDrop: no hay items correctos para completar la actividad."

	return ""


static func get_required_item_ids(items: Array) -> Array[String]:
	var required_item_ids: Array[String] = []
	for raw_item in items:
		var item: Dictionary = raw_item as Dictionary
		var correct_target: String = str(item.get("correct_target", "")).strip_edges()
		if correct_target.is_empty():
			continue
		required_item_ids.append(str(item.get("id", "")).strip_edges())
	return required_item_ids
