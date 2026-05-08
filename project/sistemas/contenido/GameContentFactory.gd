extends RefCounted
class_name GameContentFactory

const ContentCatalogScript := preload("res://sistemas/contenido/ContentCatalog.gd")
const ContentNormalizerScript := preload("res://sistemas/contenido/ContentNormalizer.gd")

const MODE_DRAG_DROP := "drag_drop"
const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_VINCULACION_CONCEPTOS := "vinculacion_conceptos"


static func create_runtime_game(raw_data: Dictionary, source_path: String = "") -> Dictionary:
	var normalized_result: Dictionary = ContentNormalizerScript.normalize(raw_data, source_path)
	var normalized_data: Dictionary = normalized_result.get("data", {})
	if not ContentNormalizerScript.is_v1_content(normalized_data):
		return _error("GameContentFactory solo soporta contenido V1.")

	match str(normalized_data.get("tipo", "")):
		"receta_arrastre", "arrastre":
			return _create_drag_drop_runtime(normalized_data)
		"preguntas":
			return _create_questions_runtime(normalized_data)
		"vinculacion":
			return _create_linking_runtime(normalized_data)
		_:
			return _error(
				"El archivo no es jugable directo: %s" % str(normalized_data.get("tipo", ""))
			)


static func _create_drag_drop_runtime(data: Dictionary) -> Dictionary:
	var target_label: String = str(data.get("label_objetivo", "")).strip_edges()
	if target_label.is_empty():
		target_label = "Plato"

	var items: Array[Dictionary] = []
	items.append_array(
		_build_drag_items(data.get("correctos", data.get("items_correctos", [])), true)
	)
	items.append_array(
		_build_drag_items(data.get("incorrectos", data.get("items_incorrectos", [])), false)
	)

	var runtime_data := {
		"id": str(data.get("id", "")).strip_edges(),
		"theme": str(data.get("categoria", "")).strip_edges(),
		"title": str(data.get("titulo", "")).strip_edges(),
		"difficulty": _to_runtime_difficulty(int(data.get("dificultad", 1))),
		"mode": MODE_DRAG_DROP,
		"content": {
			"instruction": str(data.get("objetivo", "")).strip_edges(),
			"teaching_key": str(data.get("teaching_key", "")).strip_edges(),
			"targets": [{"id": "plato", "label": target_label}],
			"items": items,
			"elementos_maximos": int(data.get("cantidad_correctos", 0))
				+ int(data.get("cantidad_incorrectos", 0)),
			"distractores_maximos": int(data.get("cantidad_incorrectos", 0)),
			"mostrar_ayuda_visual": bool(data.get("mostrar_ayuda_visual", false)),
			"feedback": data.get("feedback", {}),
		}
	}
	return _ok(runtime_data)


static func _build_drag_items(item_ids: Array[String], is_correct: bool) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var repeated_ids: Dictionary = {}
	for item_id in item_ids:
		var runtime_result: Dictionary = ContentCatalogScript.resolve_item_runtime_data(item_id)
		if not bool(runtime_result.get("ok", false)):
			continue
		var runtime_data: Dictionary = runtime_result.get("data", {})
		var copies: int = int(repeated_ids.get(item_id, 0)) + 1
		repeated_ids[item_id] = copies
		var runtime_item_id: String = item_id
		if copies > 1:
			runtime_item_id = "%s_%d" % [item_id, copies]
		items.append(
			{
				"id": runtime_item_id,
				"label": str(runtime_data.get("nombre", item_id)).strip_edges(),
				"image": str(runtime_data.get("image", "")).strip_edges(),
				"correct_target": "plato" if is_correct else "",
				"category": str(runtime_data.get("categoria", "")).strip_edges(),
				"info_image": str(runtime_data.get("info_image", "")).strip_edges(),
			}
		)
	return items


static func _create_questions_runtime(data: Dictionary) -> Dictionary:
	var runtime_questions: Array[Dictionary] = []
	for raw_question in data.get("preguntas", []):
		if not raw_question is Dictionary:
			continue
		var question: Dictionary = raw_question as Dictionary
		var correct_answer: String = ""
		var wrong_options: Array[String] = []
		for raw_option in question.get("opciones", []):
			if not raw_option is Dictionary:
				continue
			var option: Dictionary = raw_option as Dictionary
			var option_text: String = str(option.get("texto", "")).strip_edges()
			if option_text.is_empty():
				continue
			if bool(option.get("correcta", false)):
				correct_answer = option_text
			else:
				wrong_options.append(option_text)
		runtime_questions.append(
			{
				"id": str(question.get("id", "")).strip_edges(),
				"question": str(question.get("enunciado", "")).strip_edges(),
				"correct_answer": correct_answer,
				"wrong_options": wrong_options,
				"explanation": str(question.get("explicacion", "")).strip_edges(),
			}
		)

	return _ok(
		{
			"id": str(data.get("id", "")).strip_edges(),
			"theme": str(data.get("categoria", "")).strip_edges(),
			"title": str(data.get("titulo", "")).strip_edges(),
			"difficulty": _to_runtime_difficulty(int(data.get("dificultad", 1))),
			"mode": MODE_QUIZ_CHOICE,
			"content": {
				"questions": runtime_questions,
			}
		}
	)


static func _create_linking_runtime(data: Dictionary) -> Dictionary:
	return _ok(
		{
			"id": str(data.get("id", "")).strip_edges(),
			"theme": str(data.get("categoria", "")).strip_edges(),
			"title": str(data.get("titulo", "")).strip_edges(),
			"difficulty": _to_runtime_difficulty(int(data.get("dificultad", 1))),
			"mode": MODE_VINCULACION_CONCEPTOS,
			"content": {
				"instruccion": str(data.get("instruccion", "")).strip_edges(),
				"teaching_key": str(data.get("teaching_key", "")).strip_edges(),
				"conceptos_izquierda": data.get("conceptos_izquierda", []).duplicate(true),
				"conceptos_derecha": data.get("conceptos_derecha", []).duplicate(true),
			}
		}
	)


static func _to_runtime_difficulty(raw_difficulty: int) -> String:
	match clampi(raw_difficulty, 1, 5):
		1, 2:
			return "easy"
		3:
			return "medium"
		_:
			return "hard"


static func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}