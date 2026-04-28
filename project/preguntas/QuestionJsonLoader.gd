extends RefCounted
class_name QuestionJsonLoader

const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const PreguntasScript := preload("res://preguntas/recursos/preguntas.gd")


static func cargar_resultado_desde_json(json_path: String) -> Dictionary:
	var node_result: Dictionary = NodeContentLoaderScript.load_node_content(json_path)
	if not bool(node_result.get("ok", false)):
		return {
			"ok": false,
			"theme": null,
			"error": str(node_result.get("error", "No se pudo cargar el JSON."))
		}

	return cargar_resultado_desde_datos_nodo(node_result["data"], json_path)


static func cargar_resultado_desde_datos_nodo(
	datos_nodo: Dictionary,
	etiqueta_origen: String = ""
) -> Dictionary:
	# Desde aca en adelante se usa formato oficial.
	var node_mode: String = str(datos_nodo.get("mode", "")).strip_edges()
	if node_mode != NodeContentLoaderScript.MODE_QUIZ_CHOICE:
		return {
			"ok": false,
			"theme": null,
			"error": "QuestionJsonLoader solo soporta quiz_choice. Archivo: %s" % etiqueta_origen
		}

	var content: Dictionary = datos_nodo.get("content", {})
	var runtime_question: Preguntas = _construir_pregunta_runtime(content, etiqueta_origen)
	if runtime_question == null:
		return {
			"ok": false,
			"theme": null,
			"error": "No se pudo construir la pregunta desde el JSON. Archivo: %s" % etiqueta_origen
		}

	var theme: ThemePreg = _construir_tema_con_una_pregunta(runtime_question)
	return {
		"ok": true,
		"theme": theme,
		"error": ""
	}


static func cargar_tema_desde_sesion(session_context: Dictionary) -> Dictionary:
	var datos_nodo: Dictionary = _leer_datos_nodo_de_sesion(session_context)
	if not datos_nodo.is_empty():
		return cargar_resultado_desde_datos_nodo(
			datos_nodo,
			str(session_context.get("question_json_path", "")).strip_edges()
		)

	var node_json_path: String = str(session_context.get("question_json_path", "")).strip_edges()
	if not node_json_path.is_empty():
		var json_result: Dictionary = cargar_resultado_desde_json(node_json_path)
		if bool(json_result.get("ok", false)):
			return json_result
		var theme_legacy_desde_json: ThemePreg = _cargar_tema_legacy_desde_sesion(session_context)
		if theme_legacy_desde_json != null:
			return {
				"ok": true,
				"theme": theme_legacy_desde_json,
				"error": ""
			}
		return json_result

	var theme_legacy: ThemePreg = _cargar_tema_legacy_desde_sesion(session_context)
	if theme_legacy == null:
		return {
			"ok": false,
			"theme": null,
			"error": "No se pudo cargar el contenido del nodo. Revisa su JSON o el recurso fallback."
		}

	return {
		"ok": true,
		"theme": theme_legacy,
		"error": ""
	}


static func _leer_datos_nodo_de_sesion(session_context: Dictionary) -> Dictionary:
	var raw_node_data: Variant = session_context.get("node_content", {})
	if raw_node_data is Dictionary:
		return (raw_node_data as Dictionary).duplicate(true)
	return {}


static func _cargar_tema_legacy_desde_sesion(session_context: Dictionary) -> ThemePreg:
	# Compatibilidad temporal: formato viejo con recurso `.tres`.
	var question_resource_path: String = str(
		session_context.get("question_resource_path", "")
	).strip_edges()
	if question_resource_path.is_empty():
		return null

	var question_resource: Preguntas = _cargar_pregunta_legacy(question_resource_path)
	if question_resource == null:
		return null
	return _construir_tema_con_una_pregunta(question_resource)


static func _cargar_pregunta_legacy(question_resource_path: String) -> Preguntas:
	var question_resource: Variant = load(question_resource_path)
	if question_resource == null:
		push_warning(
			"QuestionJsonLoader: no se pudo cargar la pregunta fallback: %s"
			% question_resource_path
		)
		return null
	if not question_resource is Preguntas:
		push_warning(
			"QuestionJsonLoader: el recurso fallback no es una pregunta valida: %s"
			% question_resource_path
		)
		return null
	return question_resource as Preguntas


static func _construir_tema_con_una_pregunta(question_resource: Preguntas) -> ThemePreg:
	var theme: ThemePreg = ThemePregScript.new()
	var questions: Array[Preguntas] = [question_resource]
	theme.theme = questions
	return theme


static func _construir_pregunta_runtime(content: Dictionary, etiqueta_origen: String) -> Preguntas:
	var correct_answer: String = str(content.get("correct_answer", "")).strip_edges()
	var question_texture: Texture2D = _cargar_recurso_visual(
		str(content.get("visual_resource", "")).strip_edges(),
		etiqueta_origen
	)

	var question: Preguntas = PreguntasScript.new()
	question.info_pregunta = str(content.get("question", "")).strip_edges()
	question.correct = correct_answer
	question.opciones = _construir_opciones(content, correct_answer)
	question.tipo = Enum.TipoPregunta.IMAGEN if question_texture != null else Enum.TipoPregunta.TEXTO
	question.pregunta_imagen = question_texture
	return question


static func _construir_opciones(content: Dictionary, correct_answer: String) -> Array[String]:
	var options: Array[String] = []
	if not correct_answer.is_empty():
		options.append(correct_answer)

	var wrong_options: Array = content.get("wrong_options", [])
	for raw_wrong_option in wrong_options:
		var wrong_option: String = str(raw_wrong_option).strip_edges()
		if wrong_option.is_empty():
			continue
		if options.has(wrong_option):
			continue
		options.append(wrong_option)

	return options


static func _cargar_recurso_visual(visual_path: String, etiqueta_origen: String) -> Texture2D:
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
