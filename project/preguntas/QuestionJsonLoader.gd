extends RefCounted
class_name QuestionJsonLoader
## Loader simple para convertir un JSON de nodo en un ThemePreg.
##
## Regla mental trainee:
## - abre archivo
## - valida JSON
## - obtiene preguntas
## - crea preguntas runtime

const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const PreguntasScript := preload("res://preguntas/recursos/preguntas.gd")

const TYPE_TEXT := 0
const TYPE_IMAGE := 1
const TYPE_AUDIO := 2
const TYPE_VIDEO := 3
const ACTIVITY_TYPE_QUIZ_CHOICE := "quiz_choice"
const ACTIVITY_TYPE_SELECT_OPTION := "select_option"
const ACTIVITY_TYPE_DRAG_TO_TARGET := "drag_to_target"
const ACTIVITY_TYPE_TITLE_CARD := "title_card"


static func cargar_tema_desde_archivo_json(
	json_path: String,
	errors: Array[String],
	warnings: Array[String]
) -> ThemePreg:
	errors.clear()
	warnings.clear()

	var clean_path: String = json_path.strip_edges()
	if clean_path.is_empty():
		errors.append("Falta la ruta del JSON.")
		return null

	if not FileAccess.file_exists(clean_path):
		errors.append("No existe el archivo JSON: %s" % clean_path)
		return null

	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		errors.append("No se pudo abrir el archivo JSON: %s" % clean_path)
		return null

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("El JSON debe tener un objeto raiz.")
		return null

	var root: Dictionary = parsed as Dictionary
	var activity_type: String = _obtener_tipo_de_actividad(root)
	if activity_type == ACTIVITY_TYPE_DRAG_TO_TARGET:
		errors.append(
			"La escena de preguntas no soporta drag_to_target. Este JSON sirve como schema, pero necesita otra escena runtime."
		)
		return null
	if activity_type == ACTIVITY_TYPE_TITLE_CARD:
		errors.append(
			"La escena de preguntas no soporta title_card. Este JSON sirve como schema, pero necesita otra escena runtime."
		)
		return null

	var bloques_de_pregunta: Array = _obtener_bloques_de_pregunta(root, activity_type)
	if bloques_de_pregunta.is_empty():
		errors.append("El JSON debe incluir question, selection, lessons o questions.")
		return null

	var runtime_questions: Array[Preguntas] = []
	for lesson_index in range(bloques_de_pregunta.size()):
		var raw_lesson: Variant = bloques_de_pregunta[lesson_index]
		if not raw_lesson is Dictionary:
			errors.append("Leccion %d: debe ser un objeto." % (lesson_index + 1))
			continue

		var question: Preguntas = _build_question(
			raw_lesson as Dictionary,
			lesson_index + 1,
			warnings,
			errors
		)
		if question != null:
			runtime_questions.append(question)

	if runtime_questions.is_empty():
		errors.append("No se pudo construir ninguna pregunta valida.")
		return null

	if not errors.is_empty():
		return null

	var theme: ThemePreg = ThemePregScript.new()
	theme.theme = runtime_questions
	return theme


static func _obtener_tipo_de_actividad(root: Dictionary) -> String:
	var activity_data: Dictionary = _obtener_bloque_activity(root)
	var activity_type: String = str(activity_data.get("type", "")).strip_edges().to_lower()
	if not activity_type.is_empty():
		return activity_type

	if root.get("selection", null) is Dictionary:
		return ACTIVITY_TYPE_SELECT_OPTION
	if root.get("question", null) is Dictionary:
		return ACTIVITY_TYPE_QUIZ_CHOICE
	if _parece_json_de_pregunta_simple(root):
		return ACTIVITY_TYPE_QUIZ_CHOICE
	return ""


static func _obtener_bloque_activity(root: Dictionary) -> Dictionary:
	var raw_activity: Variant = root.get("activity", {})
	if raw_activity is Dictionary:
		return raw_activity as Dictionary
	return {}


static func _obtener_bloques_de_pregunta(root: Dictionary, activity_type: String) -> Array:
	if activity_type == ACTIVITY_TYPE_SELECT_OPTION:
		var bloque_de_seleccion: Variant = root.get("selection", null)
		if bloque_de_seleccion is Dictionary:
			return [bloque_de_seleccion]

	var bloque_de_pregunta: Variant = root.get("question", null)
	if bloque_de_pregunta is Dictionary:
		return [bloque_de_pregunta]

	var pregunta_simple: Variant = root.get("question", root.get("lesson", null))
	if pregunta_simple is Dictionary:
		return [pregunta_simple]

	var preguntas_en_lista: Variant = root.get("questions", root.get("lessons", []))
	if preguntas_en_lista is Array:
		return preguntas_en_lista as Array

	var raw_node: Variant = root.get("node", {})
	if raw_node is Dictionary:
		var pregunta_simple_en_node: Variant = (raw_node as Dictionary).get(
			"question",
			(raw_node as Dictionary).get("lesson", null)
		)
		if pregunta_simple_en_node is Dictionary:
			return [pregunta_simple_en_node]

		var preguntas_en_lista_en_node: Variant = (raw_node as Dictionary).get(
			"questions",
			(raw_node as Dictionary).get("lessons", [])
		)
		if preguntas_en_lista_en_node is Array:
			return preguntas_en_lista_en_node as Array

	if _parece_json_de_pregunta_simple(root):
		return [root]
	return []


static func _parece_json_de_pregunta_simple(root: Dictionary) -> bool:
	var has_prompt: bool = not _leer_primer_texto_disponible(
		root,
		["prompt", "consigna", "question", "info_pregunta"]
	).is_empty()
	var has_correct_answer: bool = not _leer_primer_texto_disponible(
		root,
		["correct_answer", "respuesta_correcta", "correct"]
	).is_empty()
	return has_prompt and has_correct_answer


static func _build_question(
	lesson_data: Dictionary,
	lesson_number: int,
	warnings: Array[String],
	errors: Array[String]
) -> Preguntas:
	var prompt: String = _leer_primer_texto_disponible(
		lesson_data,
		["prompt", "instruction", "consigna", "question", "info_pregunta"]
	)
	if prompt.is_empty():
		errors.append("Leccion %d: falta prompt." % lesson_number)
		return null

	var correct_answer: String = _leer_primer_texto_disponible(
		lesson_data,
		["correct_answer", "correct_option", "respuesta_correcta", "correct"]
	)
	if correct_answer.is_empty():
		errors.append("Leccion %d: falta correct_answer." % lesson_number)
		return null

	var options: Array[String] = _construir_opciones_de_respuesta(lesson_data, correct_answer)
	if options.size() < 2:
		warnings.append("Leccion %d: tiene menos de 2 opciones." % lesson_number)

	var question: Preguntas = PreguntasScript.new()
	question.info_pregunta = prompt
	question.correct = correct_answer
	question.opciones = options
	question.tipo = _leer_tipo_de_pregunta(lesson_data)
	question.pregunta_imagen = _load_texture(_leer_ruta_de_recurso(lesson_data, "image_path"), lesson_number, warnings)
	question.pregunta_audio = _load_audio(_leer_ruta_de_recurso(lesson_data, "audio_path"), lesson_number, warnings)
	question.pregunta_video = _load_video(_leer_ruta_de_recurso(lesson_data, "video_path"), lesson_number, warnings)
	return question


static func _construir_opciones_de_respuesta(
	lesson_data: Dictionary,
	correct_answer: String
) -> Array[String]:
	var options: Array[String] = _leer_array_de_textos(
		lesson_data.get("options", lesson_data.get("opciones", lesson_data.get("choices", [])))
	)
	if options.is_empty():
		options.append(correct_answer)
		var wrong_answers: Array[String] = _leer_array_de_textos(
			lesson_data.get(
				"wrong_answers",
				lesson_data.get("opciones_incorrectas", lesson_data.get("wrong_options", []))
			)
		)
		for wrong_answer in wrong_answers:
			if wrong_answer == correct_answer:
				continue
			options.append(wrong_answer)

	if not options.has(correct_answer):
		options.append(correct_answer)

	return options


static func _leer_tipo_de_pregunta(lesson_data: Dictionary) -> int:
	var raw_type: String = _leer_primer_texto_disponible(lesson_data, ["type", "tipo"])
	match raw_type.to_lower():
		"image", "imagen":
			return TYPE_IMAGE
		"audio":
			return TYPE_AUDIO
		"video":
			return TYPE_VIDEO
		_:
			return TYPE_TEXT


static func _leer_ruta_de_recurso(lesson_data: Dictionary, asset_key: String) -> String:
	var raw_assets: Variant = lesson_data.get("assets", {})
	if raw_assets is Dictionary:
		var nested_value: String = str((raw_assets as Dictionary).get(asset_key, "")).strip_edges()
		if not nested_value.is_empty():
			return nested_value

	match asset_key:
		"image_path":
			return _leer_primer_texto_disponible(
				lesson_data,
				["image_path", "imagen_path", "pregunta_imagen"]
			)
		"audio_path":
			return _leer_primer_texto_disponible(lesson_data, ["audio_path", "pregunta_audio"])
		"video_path":
			return _leer_primer_texto_disponible(lesson_data, ["video_path", "pregunta_video"])
		_:
			return ""


static func _load_texture(path: String, lesson_number: int, warnings: Array[String]) -> Texture2D:
	if path.is_empty():
		return null
	var resource: Variant = load(path)
	if resource is Texture2D:
		return resource as Texture2D
	warnings.append("Leccion %d: image_path invalido (%s)." % [lesson_number, path])
	return null


static func _load_audio(path: String, lesson_number: int, warnings: Array[String]) -> AudioStream:
	if path.is_empty():
		return null
	var resource: Variant = load(path)
	if resource is AudioStream:
		return resource as AudioStream
	warnings.append("Leccion %d: audio_path invalido (%s)." % [lesson_number, path])
	return null


static func _load_video(path: String, lesson_number: int, warnings: Array[String]) -> VideoStream:
	if path.is_empty():
		return null
	var resource: Variant = load(path)
	if resource is VideoStream:
		return resource as VideoStream
	warnings.append("Leccion %d: video_path invalido (%s)." % [lesson_number, path])
	return null


static func _leer_primer_texto_disponible(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		if not source.has(key):
			continue
		var value: String = str(source.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


static func _leer_array_de_textos(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values

	for raw_value in raw_values:
		var value: String = str(raw_value).strip_edges()
		if value.is_empty():
			continue
		values.append(value)
	return values
