extends RefCounted
class_name GameContentFactory

# LEGACY_COMPAT: Usado por CargadorDeContenidoDeNodo.
# No agregar lógica nueva aquí; el contenido nuevo entra por NodeContentLoader.

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
	var overlap_ids: Array[String] = _intersect_item_ids(
		data.get("correctos", data.get("items_correctos", [])),
		data.get("incorrectos", data.get("items_incorrectos", []))
	)
	if not overlap_ids.is_empty():
		return _error("Item repetido entre correctos e incorrectos: %s" % ", ".join(overlap_ids))

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var warnings: Array[String] = []
	var target_label: String = str(data.get("label_objetivo", "")).strip_edges()
	if target_label.is_empty():
		target_label = "Plato"
	var correct_sample_result: Dictionary = sample_drag_pool_ids(
		data.get("correctos", data.get("items_correctos", [])),
		int(data.get("cantidad_correctos", 0)),
		"cantidad_correctos",
		rng
	)
	if not bool(correct_sample_result.get("ok", false)):
		return correct_sample_result
	var wrong_sample_result: Dictionary = sample_drag_pool_ids(
		data.get("incorrectos", data.get("items_incorrectos", [])),
		int(data.get("cantidad_incorrectos", 0)),
		"cantidad_incorrectos",
		rng
	)
	if not bool(wrong_sample_result.get("ok", false)):
		return wrong_sample_result
	warnings.append_array(correct_sample_result.get("warnings", []))
	warnings.append_array(wrong_sample_result.get("warnings", []))

	var items: Array[Dictionary] = []
	var correct_items_result: Dictionary = _build_drag_items(
		correct_sample_result.get("data", []),
		true
	)
	if not bool(correct_items_result.get("ok", false)):
		return correct_items_result
	var wrong_items_result: Dictionary = _build_drag_items(
		wrong_sample_result.get("data", []),
		false
	)
	if not bool(wrong_items_result.get("ok", false)):
		return wrong_items_result
	items.append_array(correct_items_result.get("data", []))
	items.append_array(wrong_items_result.get("data", []))
	_shuffle_items(items, rng)

	var runtime_data := {
		"id": str(data.get("id", "")).strip_edges(),
		"theme": str(data.get("categoria", "")).strip_edges(),
		"title": str(data.get("titulo", "")).strip_edges(),
		"difficulty": _to_runtime_difficulty(int(data.get("dificultad", 1))),
		"mode": MODE_DRAG_DROP,
		"warnings": warnings,
		"content": {
			"instruction": str(data.get("objetivo", "")).strip_edges(),
			"teaching_key": str(data.get("teaching_key", "")).strip_edges(),
			"targets": [{"id": "plato", "label": target_label}],
			"items": items,
			"elementos_maximos": items.size(),
			"distractores_maximos": (wrong_items_result.get("data", []) as Array).size(),
			"mostrar_ayuda_visual": bool(data.get("mostrar_ayuda_visual", false)),
			"feedback": data.get("feedback", {}),
		}
	}
	return _ok(runtime_data)


static func sample_drag_pool_ids(
	item_ids: Array[String],
	requested_count: int,
	field_name: String,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if requested_count <= 0:
		return _error("%s invalida" % field_name)
	var unique_ids: Array[String] = _dedupe_item_ids(item_ids)
	if unique_ids.is_empty():
		return _error("Pool vacio para %s" % field_name)
	var active_rng: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		active_rng.randomize()
	var shuffled_ids: Array[String] = unique_ids.duplicate()
	_shuffle_ids(shuffled_ids, active_rng)
	var sample_count: int = mini(requested_count, shuffled_ids.size())
	var warnings: Array[String] = []
	if requested_count > shuffled_ids.size():
		var warning_message: String = (
			"%s supera el pool disponible; se usan todos los items." % field_name
		)
		push_warning("GameContentFactory: %s" % warning_message)
		warnings.append(warning_message)
	return {
		"ok": true,
		"data": shuffled_ids.slice(0, sample_count),
		"error": "",
		"warnings": warnings,
	}


static func _build_drag_items(item_ids: Array[String], is_correct: bool) -> Dictionary:
	var items: Array[Dictionary] = []
	for item_id in item_ids:
		var runtime_result: Dictionary = ContentCatalogScript.resolve_item_runtime_data(item_id)
		if not bool(runtime_result.get("ok", false)):
			return _error(str(runtime_result.get("error", "No se pudo resolver el item.")))
		var runtime_data: Dictionary = runtime_result.get("data", {})
		items.append(
			{
				"id": item_id,
				"label": str(runtime_data.get("nombre", item_id)).strip_edges(),
				"image": str(runtime_data.get("image", "")).strip_edges(),
				"correct_target": "plato" if is_correct else "",
				"category": str(runtime_data.get("categoria", "")).strip_edges(),
				"info_image": str(runtime_data.get("info_image", "")).strip_edges(),
				"resource": str(runtime_data.get("resource", "")).strip_edges(),
			}
		)
	return _ok(items)


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
				"instruction": str(data.get("consigna", "")).strip_edges(),
				"teaching_key": str(data.get("teaching_key", "")).strip_edges(),
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


static func _ok(data: Variant) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}


static func _dedupe_item_ids(item_ids: Array[String]) -> Array[String]:
	var unique_ids: Array[String] = []
	for item_id in item_ids:
		var clean_id: String = str(item_id).strip_edges()
		if clean_id.is_empty() or unique_ids.has(clean_id):
			continue
		unique_ids.append(clean_id)
	return unique_ids


static func _intersect_item_ids(left_ids: Array[String], right_ids: Array[String]) -> Array[String]:
	var left_unique: Array[String] = _dedupe_item_ids(left_ids)
	var duplicates: Array[String] = []
	for item_id in _dedupe_item_ids(right_ids):
		if left_unique.has(item_id):
			duplicates.append(item_id)
	return duplicates


static func _shuffle_ids(item_ids: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(item_ids.size() - 1, 0, -1):
		var random_index: int = rng.randi_range(0, index)
		var temp_id: String = item_ids[index]
		item_ids[index] = item_ids[random_index]
		item_ids[random_index] = temp_id


static func _shuffle_items(items: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var random_index: int = rng.randi_range(0, index)
		var temp_item: Dictionary = items[index]
		items[index] = items[random_index]
		items[random_index] = temp_item