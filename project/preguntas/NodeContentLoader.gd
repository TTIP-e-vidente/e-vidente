extends RefCounted
class_name NodeContentLoader

const NormalizadorLegacy := preload("res://preguntas/NodeContentLegacy.gd")
const ValidadorContenido := preload("res://preguntas/NodeContentValidator.gd")

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"


static func cargar_contenido_nodo(ruta_json_nodo: String) -> Dictionary:
	var lectura_json: Dictionary = _leer_archivo_json(ruta_json_nodo)
	if lectura_json.is_empty():
		return {}

	var datos_nodo: Dictionary = NormalizadorLegacy.normalizar_datos_nodo(lectura_json)
	var mensaje_error: String = ValidadorContenido.validar_datos_nodo(datos_nodo)
	if mensaje_error.is_empty():
		mensaje_error = ValidadorContenido.validar_contenido_por_modo(datos_nodo)
		
	if not mensaje_error.is_empty():
		push_error("NodeContentLoader: " + mensaje_error)
		return {}

	return ValidadorContenido.limpiar_datos_nodo(datos_nodo)


static func _leer_archivo_json(ruta_json_nodo: String) -> Dictionary:
	var ruta_limpia: String = NormalizadorLegacy.resolver_ruta_json(ruta_json_nodo)
	if ruta_limpia.is_empty():
		push_error("NodeContentLoader: Falta la ruta del JSON.")
		return {}

	if not FileAccess.file_exists(ruta_limpia):
		push_warning("NodeContentLoader: No existe el JSON. Archivo: %s" % ruta_limpia)
		return {}

	var archivo: FileAccess = FileAccess.open(ruta_limpia, FileAccess.READ)
	if archivo == null:
		push_error("NodeContentLoader: No se pudo abrir el JSON. Archivo: %s" % ruta_limpia)
		return {}

	var parser := JSON.new()
	var resultado_parseo: Error = parser.parse(archivo.get_as_text())
	if resultado_parseo != OK:
		push_error(
			"NodeContentLoader: JSON invalido en linea %d: %s Archivo: %s"
			% [parser.get_error_line(), parser.get_error_message(), ruta_limpia]
		)
		return {}

	var datos_parseados: Variant = parser.get_data()
	if not datos_parseados is Dictionary:
		push_error("NodeContentLoader: El JSON debe ser un objeto. Archivo: %s" % ruta_limpia)
		return {}

	return datos_parseados as Dictionary
