extends RefCounted
class_name ContentJsonLoader

# LEGACY_COMPAT: Usado por CargadorDeMapa, CargadorDeContenidoDeNodo,
# ContentCatalog, ContentValidator. No agregar lógica nueva aquí.

static func load_json(json_path: String) -> Dictionary:
	var clean_path: String = resolve_path(json_path)
	if clean_path.is_empty():
		return _error("Path de archivo invalido.")
	if not FileAccess.file_exists(clean_path):
		return _error("Path de archivo invalido: %s" % json_path)

	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return _error("No se pudo abrir el archivo: %s" % clean_path)

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _error(
			"JSON invalido en %s linea %d: %s"
			% [clean_path, parser.get_error_line(), parser.get_error_message()]
		)

	var raw_data: Variant = parser.get_data()
	if not raw_data is Dictionary:
		return _error("El JSON debe ser un objeto: %s" % clean_path)

	return {
		"ok": true,
		"data": raw_data as Dictionary,
		"error": "",
		"path": clean_path,
	}


static func resolve_path(json_path: String) -> String:
	var clean_path: String = json_path.strip_edges()
	if clean_path.is_empty():
		return ""
	if FileAccess.file_exists(clean_path):
		return clean_path
	if clean_path.begins_with("project/"):
		var project_path := "res://%s" % clean_path.trim_prefix("project/")
		if FileAccess.file_exists(project_path):
			return project_path
	if clean_path.begins_with("res://project/"):
		var normalized_path := "res://%s" % clean_path.trim_prefix("res://project/")
		if FileAccess.file_exists(normalized_path):
			return normalized_path
	return clean_path


static func display_name(source_path: String) -> String:
	var clean_path: String = resolve_path(source_path)
	if clean_path.is_empty():
		return source_path.strip_edges()
	return clean_path.get_file()


static func _error(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message, "path": ""}