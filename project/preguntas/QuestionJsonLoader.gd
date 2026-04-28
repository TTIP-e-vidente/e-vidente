extends RefCounted
class_name QuestionJsonLoader

const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const PreguntasScript := preload("res://preguntas/recursos/preguntas.gd")


static func cargar_resultado_desde_datos_nodo(
	datos_nodo: Dictionary,
	etiqueta_origen: String = ""
) -> Dictionary:
	if str(datos_nodo.get("mode", "")).strip_edges() != NodeContentLoaderScript.MODE_QUIZ_CHOICE:
		return {
			"ok": false,
			"data": {},
			"error": "QuestionJsonLoader solo soporta quiz_choice. Archivo: %s" % etiqueta_origen
		}

	return {
		"ok": true,
		"data": {
			"theme": _crear_tema(_crear_pregunta(datos_nodo.get("content", {}), etiqueta_origen))
		},
		"error": ""
	}


static func cargar_tema_desde_sesion(contexto_sesion: Dictionary) -> Dictionary:
	var ruta_json: String = _ruta_json(contexto_sesion)
	var datos_nodo: Dictionary = _datos_nodo(contexto_sesion)
	if not datos_nodo.is_empty():
		return cargar_resultado_desde_datos_nodo(datos_nodo, ruta_json)

	if not ruta_json.is_empty():
		var resultado_nodo: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta_json)
		if bool(resultado_nodo.get("ok", false)):
			return cargar_resultado_desde_datos_nodo(resultado_nodo["data"], ruta_json)

		var resultado_legacy: Dictionary = _cargar_legacy(contexto_sesion)
		if bool(resultado_legacy.get("ok", false)):
			return resultado_legacy

		return {
			"ok": false,
			"data": {},
			"error": str(resultado_nodo.get("error", "No se pudo cargar el contenido del nodo."))
		}

	return _cargar_legacy(contexto_sesion)


static func _datos_nodo(contexto_sesion: Dictionary) -> Dictionary:
	var datos_nodo: Variant = contexto_sesion.get("node_data", {})
	if datos_nodo is Dictionary:
		return (datos_nodo as Dictionary).duplicate(true)
	return {}


static func _cargar_legacy(contexto_sesion: Dictionary) -> Dictionary:
	var ruta_recurso: String = _ruta_recurso_legacy(contexto_sesion)
	if ruta_recurso.is_empty():
		return {
			"ok": false,
			"data": {},
			"error": "No se pudo cargar el contenido del nodo. Revisa su JSON o el recurso fallback."
		}

	var pregunta_legacy: Preguntas = _cargar_pregunta_legacy(ruta_recurso)
	if pregunta_legacy == null:
		return {
			"ok": false,
			"data": {},
			"error": "No se pudo cargar el contenido del nodo. Revisa su JSON o el recurso fallback."
		}

	return {
		"ok": true,
		"data": {
			"theme": _crear_tema(pregunta_legacy)
		},
		"error": ""
	}


static func _ruta_json(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("node_json_path", "")).strip_edges()


static func _ruta_recurso_legacy(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("node_resource_path", "")).strip_edges()


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


static func _crear_tema(question_resource: Preguntas) -> ThemePreg:
	var theme: ThemePreg = ThemePregScript.new()
	theme.theme = [question_resource]
	return theme


static func _crear_pregunta(content: Dictionary, etiqueta_origen: String) -> Preguntas:
	var correct_answer: String = str(content.get("correct_answer", "")).strip_edges()
	var question: Preguntas = PreguntasScript.new()
	question.info_pregunta = str(content.get("question", "")).strip_edges()
	question.correct = correct_answer
	question.opciones = _opciones(content, correct_answer)
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


static func _opciones(content: Dictionary, correct_answer: String) -> Array[String]:
	var options: Array[String] = []
	if not correct_answer.is_empty():
		options.append(correct_answer)

	for raw_wrong_option in content.get("wrong_options", []):
		var wrong_option: String = str(raw_wrong_option).strip_edges()
		if wrong_option.is_empty() or options.has(wrong_option):
			continue
		options.append(wrong_option)

	return options


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
