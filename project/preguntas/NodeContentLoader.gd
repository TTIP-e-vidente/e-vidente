extends RefCounted
class_name NodeContentLoader

const NormalizadorLegacy := preload("res://preguntas/NodeContentLegacy.gd")
const ValidadorContenido := preload("res://preguntas/NodeContentValidator.gd")

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"


static func cargar_contenido_nodo(ruta_json: String) -> Dictionary:
	var resultado_lectura: Dictionary = _leer_archivo_json(ruta_json)
	if not bool(resultado_lectura.get("ok", false)):
		return resultado_lectura

	var datos_crudos: Dictionary = resultado_lectura["data"]
	var datos_nodo: Dictionary = NormalizadorLegacy.normalizar_datos_nodo(datos_crudos)
	var mensaje_error: String = ValidadorContenido.validar_datos_nodo(datos_nodo)
	if mensaje_error.is_empty():
		mensaje_error = ValidadorContenido.validar_contenido_por_modo(datos_nodo)
	if not mensaje_error.is_empty():
		return _resultado_error(mensaje_error)

	return _resultado_ok(ValidadorContenido.limpiar_datos_nodo(datos_nodo))


static func _leer_archivo_json(ruta_json: String) -> Dictionary:
	var ruta_limpia: String = NormalizadorLegacy.resolver_ruta_json(ruta_json)
	if ruta_limpia.is_empty():
		return _resultado_error("Falta la ruta del JSON.")

	if not FileAccess.file_exists(ruta_limpia):
		return _resultado_error("No existe el JSON. Archivo: %s" % ruta_limpia)

	var file: FileAccess = FileAccess.open(ruta_limpia, FileAccess.READ)
	if file == null:
		return _resultado_error("No se pudo abrir el JSON. Archivo: %s" % ruta_limpia)

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _resultado_error(
			"JSON invalido en linea %d: %s Archivo: %s"
			% [parser.get_error_line(), parser.get_error_message(), ruta_limpia]
		)

	var datos_parseados: Variant = parser.get_data()
	if not datos_parseados is Dictionary:
		return _resultado_error("El JSON debe ser un objeto. Archivo: %s" % ruta_limpia)

	return _resultado_ok(datos_parseados as Dictionary)


static func _resultado_ok(data: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error": ""
	}


static func _resultado_error(message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": message
	}
