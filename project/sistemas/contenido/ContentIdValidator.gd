extends RefCounted
class_name ContentIdValidator

## Centraliza las reglas de validación de IDs de contenido jugable.
## Todo contenido jugable debe tener un "id" que sea:
##   - Presente y no vacío.
##   - En formato snake_case (letras minúsculas, dígitos y guiones bajos; comienza con letra).
##   - Único dentro del catálogo cargado.
##
## Separar esta lógica aquí mantiene a los loaders (NodeContentLoader) y al
## historial del jugador (SaveManager) desacoplados de las reglas de formato.


## Devuelve true si el ID tiene un formato estable y válido:
##   snake_case que empieza con letra minúscula y solo contiene [a-z0-9_].
## Inválidos: vacío, con espacios, con mayúsculas, que empiecen con dígito, etc.
static func is_valid_format(id: String) -> bool:
	if id.is_empty():
		return false
	if " " in id:
		return false
	var first: String = id[0]
	if first < "a" or first > "z":
		return false
	for c in id:
		var is_lower := c >= "a" and c <= "z"
		var is_digit := c >= "0" and c <= "9"
		var is_underscore := c == "_"
		if not (is_lower or is_digit or is_underscore):
			return false
	return true


## Valida que todas las activities del array tengan IDs presentes, con formato
## válido y únicos entre sí. Devuelve un array de strings de error; vacío = válido.
## source_path se incluye en los mensajes de error para facilitar el diagnóstico.
static func validate_activity_ids(activities: Array, source_path: String = "") -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}  # id -> primer índice donde apareció
	for i in range(activities.size()):
		if not activities[i] is Dictionary:
			continue
		var activity: Dictionary = activities[i] as Dictionary
		var raw_id: String = str(activity.get("id", "")).strip_edges()
		var context: String = _position_context(source_path, "activities", i)
		if raw_id.is_empty():
			errors.append(
				'[ContentValidator] Missing required field "id" in file %s' % context
			)
			continue
		if not is_valid_format(raw_id):
			var fmt_err := '[ContentValidator] Invalid id format "%s" at %s.' % [raw_id, context]
			errors.append(fmt_err + ' Use stable snake_case ids like "node_bosque_01_quiz_001".')
		if seen_ids.has(raw_id):
			var dup_err := '[ContentValidator] Duplicate content id "%s" at %s' % [raw_id, context]
			errors.append(dup_err + ' (first seen at activities[%d])' % [int(seen_ids[raw_id])])
		else:
			seen_ids[raw_id] = i
	return errors


## Devuelve solo los ítems de all_content cuyo "id" NO esté en completed_ids.
## Los ítems sin campo "id" se conservan (no se los considera completados).
##
## Uso esperado:
##   var disponible = ContentIdValidator.filter_uncompleted(todas_las_activities, ids_completados)
static func filter_uncompleted(all_content: Array, completed_ids: Array[String]) -> Array:
	if completed_ids.is_empty():
		return all_content.duplicate()
	var result: Array = []
	for item in all_content:
		if not item is Dictionary:
			result.append(item)
			continue
		var item_id: String = str((item as Dictionary).get("id", "")).strip_edges()
		if item_id.is_empty() or not completed_ids.has(item_id):
			result.append(item)
	return result


static func _position_context(source_path: String, section: String, index: int) -> String:
	if source_path.is_empty():
		return "%s[%d]" % [section, index]
	return "%s at %s[%d]" % [source_path, section, index]
