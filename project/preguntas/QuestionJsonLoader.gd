extends RefCounted
class_name QuestionJsonLoader

const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const PreguntasScript := preload("res://preguntas/recursos/preguntas.gd")
const ERROR_CONTENIDO_NO_DISPONIBLE := "No se pudo cargar el contenido del nodo. Revisa su JSON o el recurso fallback."


static func cargar_resultado_desde_datos_nodo(
	datos_nodo: Dictionary,
	etiqueta_origen: String = ""
) -> Dictionary:
	if str(datos_nodo.get("mode", "")).strip_edges() != NodeContentLoaderScript.MODE_QUIZ_CHOICE:
		return _resultado_error(
			"QuestionJsonLoader solo soporta quiz_choice. Archivo: %s" % etiqueta_origen
		)

	var pregunta_recurso: Preguntas = _crear_pregunta(datos_nodo.get("content", {}), etiqueta_origen)
	return _resultado_ok_con_tema(_crear_tema(pregunta_recurso))


static func cargar_tema_desde_sesion(contexto_sesion: Dictionary) -> Dictionary:
	var ruta_json: String = _extraer_ruta_json_de_sesion(contexto_sesion)
	var datos_nodo: Dictionary = _extraer_datos_nodo_de_sesion(contexto_sesion)
	if not datos_nodo.is_empty():
		return cargar_resultado_desde_datos_nodo(datos_nodo, ruta_json)
	if ruta_json.is_empty():
		return _cargar_fallback_legacy(contexto_sesion)

	var resultado_nodo: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta_json)
	if bool(resultado_nodo.get("ok", false)):
		return cargar_resultado_desde_datos_nodo(resultado_nodo["data"], ruta_json)

	var resultado_legacy: Dictionary = _cargar_fallback_legacy(contexto_sesion)
	if bool(resultado_legacy.get("ok", false)):
		return resultado_legacy

	return _resultado_error(
		str(resultado_nodo.get("error", "No se pudo cargar el contenido del nodo."))
	)


static func _extraer_datos_nodo_de_sesion(contexto_sesion: Dictionary) -> Dictionary:
	var datos_nodo: Variant = contexto_sesion.get("node_data", {})
	if datos_nodo is Dictionary:
		return (datos_nodo as Dictionary).duplicate(true)
	return {}


static func _cargar_fallback_legacy(contexto_sesion: Dictionary) -> Dictionary:
	var ruta_recurso: String = _extraer_ruta_recurso_legacy_de_sesion(contexto_sesion)
	if ruta_recurso.is_empty():
		return _resultado_error(ERROR_CONTENIDO_NO_DISPONIBLE)

	var pregunta_legacy: Preguntas = _cargar_pregunta_legacy(ruta_recurso)
	if pregunta_legacy == null:
		return _resultado_error(ERROR_CONTENIDO_NO_DISPONIBLE)

	return _resultado_ok_con_tema(_crear_tema(pregunta_legacy))


static func _extraer_ruta_json_de_sesion(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("node_json_path", "")).strip_edges()


static func _extraer_ruta_recurso_legacy_de_sesion(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("node_resource_path", "")).strip_edges()


static func _resultado_ok_con_tema(tema: ThemePreg) -> Dictionary:
	return {
		"ok": true,
		"data": {
			"theme": tema
		},
		"error": ""
	}


static func _resultado_error(mensaje: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": mensaje
	}


static func _cargar_pregunta_legacy(ruta_recurso_pregunta: String) -> Preguntas:
	var pregunta_recurso: Variant = load(ruta_recurso_pregunta)
	if pregunta_recurso == null:
		push_warning(
			"QuestionJsonLoader: no se pudo cargar la pregunta fallback: %s"
			% ruta_recurso_pregunta
		)
		return null
	if not pregunta_recurso is Preguntas:
		push_warning(
			"QuestionJsonLoader: el recurso fallback no es una pregunta valida: %s"
			% ruta_recurso_pregunta
		)
		return null
	return pregunta_recurso as Preguntas


static func _crear_tema(pregunta_recurso: Preguntas) -> ThemePreg:
	var theme: ThemePreg = ThemePregScript.new()
	theme.theme = [pregunta_recurso]
	return theme


static func _crear_pregunta(content: Dictionary, etiqueta_origen: String) -> Preguntas:
	var correct_answer: String = str(content.get("correct_answer", "")).strip_edges()
	var question: Preguntas = PreguntasScript.new()
	question.info_pregunta = str(content.get("question", "")).strip_edges()
	question.correct = correct_answer
	question.opciones = _crear_opciones(content, correct_answer)
	question.pregunta_imagen = _cargar_visual(
		str(content.get("visual_resource", "")).strip_edges(),
		etiqueta_origen
	)
	question.tipo = (
		Enum.TipoPregunta.IMAGEN
		if question.pregunta_imagen != null
		else Enum.TipoPregunta.TEXTO
	)
	return question


static func _crear_opciones(content: Dictionary, correct_answer: String) -> Array[String]:
	var opciones: Array[String] = []
	if not correct_answer.is_empty():
		opciones.append(correct_answer)

	for raw_wrong_option in content.get("wrong_options", []):
		var wrong_option: String = str(raw_wrong_option).strip_edges()
		if wrong_option.is_empty() or opciones.has(wrong_option):
			continue
		opciones.append(wrong_option)

	return opciones


static func _cargar_visual(visual_path: String, etiqueta_origen: String) -> Texture2D:
	if visual_path.is_empty():
		return null

	var resource: Variant = load(visual_path)
	if resource is Texture2D:
		return resource as Texture2D

	push_warning(
		"QuestionJsonLoader: visual_resource invalido (%s). Archivo: %s"
		% [visual_path, etiqueta_origen]
	)
	return null
