extends RefCounted
class_name QuestionJsonLoader

const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const PreguntasScript := preload("res://preguntas/recursos/preguntas.gd")


static func cargar_resultado_desde_archivo_json(json_path: String) -> Dictionary:
	var node_result: Dictionary = NodeContentLoaderScript.load_node_content(json_path)
	if not bool(node_result.get("ok", false)):
		return {
			"ok": false,
			"theme": null,
			"error": str(node_result.get("error", "No se pudo cargar el JSON."))
		}

	return cargar_resultado_desde_node_data(node_result["data"], json_path)


static func cargar_resultado_desde_node_data(
	node_data: Dictionary,
	source_label: String = ""
) -> Dictionary:
	# Formato oficial despues del loader: {id, theme, title, difficulty, mode, content}
	var node_mode: String = str(node_data.get("mode", "")).strip_edges()
	if node_mode != NodeContentLoaderScript.MODE_QUIZ_CHOICE:
		return {
			"ok": false,
			"theme": null,
			"error": "QuestionJsonLoader solo soporta quiz_choice. Archivo: %s" % source_label
		}

	var content: Dictionary = node_data.get("content", {})
	var runtime_question: Preguntas = _build_runtime_question(
		content,
		source_label
	)
	if runtime_question == null:
		return {
			"ok": false,
			"theme": null,
			"error": "No se pudo construir la pregunta desde el JSON. Archivo: %s" % source_label
		}

	var theme: ThemePreg = ThemePregScript.new()
	var questions: Array[Preguntas] = [runtime_question]
	theme.theme = questions
	return {
		"ok": true,
		"theme": theme,
		"error": ""
	}


static func _build_runtime_question(content: Dictionary, json_path: String) -> Preguntas:
	var correct_answer: String = str(content.get("correct_answer", "")).strip_edges()
	var question_texture: Texture2D = _load_visual_resource(
		str(content.get("visual_resource", "")).strip_edges(),
		json_path
	)

	var question: Preguntas = PreguntasScript.new()
	question.info_pregunta = str(content.get("question", "")).strip_edges()
	question.correct = correct_answer
	question.opciones = _build_options(content, correct_answer)
	question.tipo = Enum.TipoPregunta.IMAGEN if question_texture != null else Enum.TipoPregunta.TEXTO
	question.pregunta_imagen = question_texture
	return question


static func _build_options(content: Dictionary, correct_answer: String) -> Array[String]:
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


static func _load_visual_resource(visual_path: String, json_path: String) -> Texture2D:
	if visual_path.is_empty():
		return null

	var resource: Variant = load(visual_path)
	if resource is Texture2D:
		return resource as Texture2D

	push_warning(
		"QuestionJsonLoader: visual_resource invalido (%s). Archivo: %s"
		% [visual_path, json_path]
	)
	return null
