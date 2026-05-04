extends RefCounted
class_name NodeContentLoader

const NodeContentLegacyScript := preload("res://sistemas/contenido/NodeContentLegacy.gd")
const NodeContentValidatorScript := preload("res://sistemas/contenido/NodeContentValidator.gd")

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"


# Punto unico de entrada para JSON de lecciones.
# Flujo nuevo: leer archivo oficial desde res://contenido/nodos/*,
# normalizar solo si el contenido es viejo y devolver un nodo limpio.
# Toda compatibilidad legacy debe vivir en NodeContentLegacy.gd.


static func load_node_content(json_path: String) -> Dictionary:
	var raw_data: Dictionary = read_json_file(json_path)
	if raw_data.is_empty():
		return _result_error("No se pudo leer el JSON: %s" % json_path)

	var node_data: Dictionary = normalize_legacy_if_needed(raw_data)
	var validation_error: String = validate(node_data)
	if not validation_error.is_empty():
		push_error("NodeContentLoader: " + validation_error)
		return _result_error(validation_error)

	return _result_ok(NodeContentValidatorScript.clean(node_data))


static func cargar_contenido_nodo(ruta_json_nodo: String) -> Dictionary:
	return load_node_content(ruta_json_nodo)


static func read_json_file(json_path: String) -> Dictionary:
	var clean_path: String = NodeContentLegacyScript.resolve_json_path(json_path)
	if clean_path.is_empty():
		push_error("NodeContentLoader: Falta la ruta del JSON.")
		return {}

	if not FileAccess.file_exists(clean_path):
		push_warning("NodeContentLoader: No existe el JSON. Archivo: %s" % clean_path)
		return {}

	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		push_error("NodeContentLoader: No se pudo abrir el JSON. Archivo: %s" % clean_path)
		return {}

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		push_error(
			"NodeContentLoader: JSON invalido en linea %d: %s Archivo: %s"
			% [parser.get_error_line(), parser.get_error_message(), clean_path]
		)
		return {}

	var parsed_data: Variant = parser.get_data()
	if not parsed_data is Dictionary:
		push_error("NodeContentLoader: El JSON debe ser un objeto. Archivo: %s" % clean_path)
		return {}

	return parsed_data as Dictionary


static func normalize_legacy_if_needed(raw_data: Dictionary) -> Dictionary:
	return NodeContentLegacyScript.normalize_node_data(raw_data)


static func validate(node_data: Dictionary) -> String:
	return NodeContentValidatorScript.validate(node_data)


static func _leer_archivo_json(ruta_json_nodo: String) -> Dictionary:
	return read_json_file(ruta_json_nodo)


static func _result_ok(datos_nodo: Dictionary) -> Dictionary:
	return { "ok": true, "data": datos_nodo, "error": "" }


static func _result_error(mensaje: String) -> Dictionary:
	return { "ok": false, "data": {}, "error": mensaje }
