extends RefCounted
class_name NodeContentLoader

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"
const CURRENT_NODE_JSON_DIR := "res://niveles/nodos/"
const LEGACY_NODE_JSON_DIR := "res://preguntas/json_nodos/"
const CURRENT_PROJECT_NODE_JSON_DIR := "project/niveles/nodos/"
const LEGACY_PROJECT_NODE_JSON_DIR := "project/preguntas/json_nodos/"


static func load_node_content(json_path: String) -> Dictionary:
	var root_result: Dictionary = _read_json_root(json_path)
	if not bool(root_result.get("ok", false)):
		return root_result

	var raw_data: Dictionary = root_result["data"]
	var normalized_data: Dictionary = normalize_node_data(raw_data)
	var validation_error: String = validate_node_data(normalized_data)
	if validation_error.is_empty():
		validation_error = validate_mode_content(normalized_data)
	if not validation_error.is_empty():
		return _resultado_error(validation_error)

	return _resultado_ok(_clean_node_data(normalized_data))


static func cargar_contenido_nodo(json_path: String) -> Dictionary:
	return load_node_content(json_path)


static func normalize_node_data(raw_data: Dictionary) -> Dictionary:
	return _normalize_node_data(raw_data)


static func validate_node_data(data: Dictionary) -> String:
	return _validate_node_data(data)


static func validate_mode_content(data: Dictionary) -> String:
	return _validate_mode_content(data)


static func _read_json_root(json_path: String) -> Dictionary:
	var clean_path: String = _resolve_json_path(json_path)
	if clean_path.is_empty():
		return _resultado_error("Falta la ruta del JSON.")

	if not FileAccess.file_exists(clean_path):
		return _resultado_error("No existe el JSON. Archivo: %s" % clean_path)

	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return _resultado_error("No se pudo abrir el JSON. Archivo: %s" % clean_path)

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _resultado_error(
			"JSON invalido en linea %d: %s Archivo: %s"
			% [parser.get_error_line(), parser.get_error_message(), clean_path]
		)

	var parsed_data: Variant = parser.get_data()
	if not parsed_data is Dictionary:
		return _resultado_error("El JSON debe ser un objeto. Archivo: %s" % clean_path)

	return _resultado_ok(parsed_data as Dictionary)


static func _resolve_json_path(json_path: String) -> String:
	var clean_path: String = json_path.strip_edges()
	if clean_path.is_empty():
		return ""

	if FileAccess.file_exists(clean_path):
		return clean_path

	var migrated_path: String = clean_path
	if clean_path.begins_with(LEGACY_NODE_JSON_DIR):
		migrated_path = "%s%s" % [CURRENT_NODE_JSON_DIR, clean_path.trim_prefix(LEGACY_NODE_JSON_DIR)]
	elif clean_path.begins_with(LEGACY_PROJECT_NODE_JSON_DIR):
		migrated_path = "%s%s" % [
			CURRENT_PROJECT_NODE_JSON_DIR,
			clean_path.trim_prefix(LEGACY_PROJECT_NODE_JSON_DIR)
		]

	if migrated_path != clean_path and FileAccess.file_exists(migrated_path):
		push_warning(
			"NodeContentLoader: ruta legacy detectada. Usa %s en lugar de %s."
			% [migrated_path, clean_path]
		)
		return migrated_path

	return clean_path


static func _normalize_node_data(raw_data: Dictionary) -> Dictionary:
	if _parece_formato_oficial(raw_data):
		return raw_data.duplicate(true)
	if _parece_quiz_plano(raw_data):
		return _normalizar_quiz_plano(raw_data)
	return _normalizar_nodo_legacy(raw_data)


static func _parece_formato_oficial(raw_data: Dictionary) -> bool:
	return (
		raw_data.has("id")
		and raw_data.has("theme")
		and raw_data.has("title")
		and raw_data.has("difficulty")
		and raw_data.has("mode")
		and raw_data.has("content")
	)


static func _parece_quiz_plano(raw_data: Dictionary) -> bool:
	return (
		raw_data.has("id")
		and raw_data.has("theme")
		and raw_data.has("title")
		and raw_data.has("difficulty")
		and raw_data.has("mode")
		and raw_data.has("question")
		and raw_data.has("correct_answer")
		and raw_data.has("wrong_options")
	)


static func _normalizar_quiz_plano(raw_data: Dictionary) -> Dictionary:
	return {
		"id": str(raw_data.get("id", "")).strip_edges(),
		"theme": str(raw_data.get("theme", "")).strip_edges(),
		"title": str(raw_data.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(raw_data.get("difficulty", "")).strip_edges()),
		"mode": _normalizar_modo(str(raw_data.get("mode", "")).strip_edges()),
		"content": {
			"question": str(raw_data.get("question", "")).strip_edges(),
			"correct_answer": str(raw_data.get("correct_answer", "")).strip_edges(),
			"wrong_options": _limpiar_array_de_textos(raw_data.get("wrong_options", [])),
			"visual_resource": str(raw_data.get("visual_resource", "")).strip_edges()
		}
	}


static func _normalizar_nodo_legacy(raw_data: Dictionary) -> Dictionary:
	var node_data: Dictionary = _leer_diccionario(raw_data.get("node", {}))
	var activity_data: Dictionary = _leer_diccionario(raw_data.get("activity", {}))
	var mode: String = _normalizar_modo(str(activity_data.get("type", "")).strip_edges())

	match mode:
		MODE_QUIZ_CHOICE:
			var quiz_block: Dictionary = _leer_diccionario(raw_data.get("question", {}))
			if str(activity_data.get("type", "")).strip_edges() == "select_option":
				quiz_block = _leer_diccionario(raw_data.get("selection", {}))
			return _construir_nodo_quiz(node_data, mode, quiz_block)
		MODE_DRAG_DROP:
			return _construir_nodo_drag_drop(
				node_data,
				mode,
				activity_data,
				_leer_diccionario(raw_data.get("drag_and_drop", {}))
			)
		_:
			return {
				"id": str(node_data.get("question_key", "")).strip_edges(),
				"theme": str(node_data.get("track_key", "")).strip_edges(),
				"title": str(node_data.get("title", "")).strip_edges(),
				"difficulty": _normalizar_dificultad(str(node_data.get("difficulty", "")).strip_edges()),
				"mode": mode,
				"content": _leer_diccionario(
					raw_data.get(
						"title_card",
						raw_data.get("drag_and_drop", raw_data.get("question", raw_data.get("selection", {})))
					)
				)
			}


static func _construir_nodo_quiz(node_data: Dictionary, mode: String, quiz_block: Dictionary) -> Dictionary:
	return {
		"id": str(node_data.get("question_key", "")).strip_edges(),
		"theme": str(node_data.get("track_key", "")).strip_edges(),
		"title": str(node_data.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(node_data.get("difficulty", "")).strip_edges()),
		"mode": mode,
		"content": {
			"question": _leer_primer_texto(quiz_block, ["question", "prompt", "instruction", "consigna"]),
			"correct_answer": _leer_primer_texto(
				quiz_block,
				["correct_answer", "correct_option", "respuesta_correcta", "correct"]
			),
			"wrong_options": _leer_opciones_incorrectas(quiz_block),
			"visual_resource": _leer_recurso_visual(quiz_block)
		}
	}


static func _construir_nodo_drag_drop(
	node_data: Dictionary,
	mode: String,
	activity_data: Dictionary,
	drag_block: Dictionary
) -> Dictionary:
	var target_data: Dictionary = _leer_diccionario(drag_block.get("target", {}))
	var targets: Array[Dictionary] = _leer_targets(drag_block, target_data)
	var default_target_id: String = ""
	if not targets.is_empty():
		default_target_id = str(targets[0].get("id", "")).strip_edges()
	var instruction: String = _leer_primer_texto(drag_block, ["instruction", "prompt"])
	if instruction.is_empty():
		instruction = str(activity_data.get("instruction", "")).strip_edges()

	return {
		"id": str(node_data.get("question_key", "")).strip_edges(),
		"theme": str(node_data.get("track_key", "")).strip_edges(),
		"title": str(node_data.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(node_data.get("difficulty", "")).strip_edges()),
		"mode": mode,
		"content": {
			"instruction": instruction,
			"targets": targets,
			"items": _leer_items_drag_drop(drag_block, default_target_id),
			"success_message": _leer_primer_texto(drag_block, ["success_message", "success"]),
			"error_message": _leer_primer_texto(
				drag_block,
				["error_message", "error", "failure_message"]
			)
		}
	}


static func _validate_node_data(data: Dictionary) -> String:
	for field in ["id", "theme", "title", "difficulty", "mode", "content"]:
		if not data.has(field):
			return "Falta el campo obligatorio: %s" % field

	if str(data.get("id", "")).strip_edges().is_empty():
		return "El campo id no puede estar vacio."
	if str(data.get("theme", "")).strip_edges().is_empty():
		return "El campo theme no puede estar vacio."
	if str(data.get("title", "")).strip_edges().is_empty():
		return "El campo title no puede estar vacio."
	if str(data.get("difficulty", "")).strip_edges().is_empty():
		return "El campo difficulty no puede estar vacio."

	var mode: String = str(data.get("mode", "")).strip_edges()
	var content: Variant = data.get("content", {})
	if not content is Dictionary:
		return "El campo content debe ser un objeto."

	return ""


static func _validate_mode_content(data: Dictionary) -> String:
	var mode: String = str(data.get("mode", "")).strip_edges()
	var content: Dictionary = _leer_diccionario(data.get("content", {}))
	if not [MODE_QUIZ_CHOICE, MODE_DRAG_DROP].has(mode):
		return "Modo no soportado: %s" % mode

	match mode:
		MODE_QUIZ_CHOICE:
			return _validar_contenido_quiz(content)
		MODE_DRAG_DROP:
			return _validar_contenido_drag_drop(content)

	return ""


static func _validar_contenido_quiz(content: Dictionary) -> String:
	if str(content.get("question", "")).strip_edges().is_empty():
		return "Quiz: falta question."
	if str(content.get("correct_answer", "")).strip_edges().is_empty():
		return "Quiz: falta correct_answer."

	var raw_wrong_options: Variant = content.get("wrong_options", [])
	if not raw_wrong_options is Array:
		return "Quiz: wrong_options debe ser una lista."
	if _limpiar_array_de_textos(raw_wrong_options as Array).is_empty():
		return "Quiz: wrong_options debe tener al menos una opcion."

	return ""


static func _validar_contenido_drag_drop(content: Dictionary) -> String:
	if str(content.get("instruction", "")).strip_edges().is_empty():
		return "DragDrop: falta instruction."

	var raw_targets: Variant = content.get("targets", [])
	if not raw_targets is Array:
		return "DragDrop: targets debe ser una lista."
	var targets: Array = raw_targets as Array
	if targets.is_empty():
		return "DragDrop: debe tener al menos un target."
	for target_index in range(targets.size()):
		if not targets[target_index] is Dictionary:
			return "DragDrop: target %d debe ser un objeto." % (target_index + 1)
		var target: Dictionary = targets[target_index] as Dictionary
		if str(target.get("id", "")).strip_edges().is_empty():
			return "DragDrop: target %d sin id." % (target_index + 1)
		if str(target.get("label", "")).strip_edges().is_empty():
			return "DragDrop: target %d sin label." % (target_index + 1)

	var raw_items: Variant = content.get("items", [])
	if not raw_items is Array:
		return "DragDrop: items debe ser una lista."
	var items: Array = raw_items as Array
	if items.is_empty():
		return "DragDrop: debe tener al menos un item."
	for item_index in range(items.size()):
		if not items[item_index] is Dictionary:
			return "DragDrop: item %d debe ser un objeto." % (item_index + 1)
		var item: Dictionary = items[item_index] as Dictionary
		if str(item.get("id", "")).strip_edges().is_empty():
			return "DragDrop: item %d sin id." % (item_index + 1)
		if str(item.get("label", "")).strip_edges().is_empty():
			return "DragDrop: item %d sin label." % (item_index + 1)
		if not item.has("image"):
			return "DragDrop: item %d sin image." % (item_index + 1)
		if not item.has("correct_target"):
			return "DragDrop: item %d sin correct_target." % (item_index + 1)

	return ""


static func _clean_node_data(data: Dictionary) -> Dictionary:
	# Formato oficial despues del loader.
	var mode: String = str(data.get("mode", "")).strip_edges()
	var content: Dictionary = _leer_diccionario(data.get("content", {}))

	return {
		"id": str(data.get("id", "")).strip_edges(),
		"theme": str(data.get("theme", "")).strip_edges(),
		"title": str(data.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(data.get("difficulty", "")).strip_edges()),
		"mode": mode,
		"content": _limpiar_contenido(mode, content)
	}


static func _limpiar_contenido(mode: String, content: Dictionary) -> Dictionary:
	match mode:
		MODE_QUIZ_CHOICE:
			return {
				"question": str(content.get("question", "")).strip_edges(),
				"correct_answer": str(content.get("correct_answer", "")).strip_edges(),
				"wrong_options": _limpiar_array_de_textos(content.get("wrong_options", [])),
				"visual_resource": str(content.get("visual_resource", "")).strip_edges()
			}
		MODE_DRAG_DROP:
			return {
				"instruction": str(content.get("instruction", "")).strip_edges(),
				"targets": _limpiar_targets(content.get("targets", [])),
				"items": _limpiar_items_drag_drop(content.get("items", [])),
				"success_message": str(content.get("success_message", "")).strip_edges(),
				"error_message": str(content.get("error_message", "")).strip_edges()
			}
	return content.duplicate(true)


static func _leer_diccionario(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return raw_value as Dictionary
	return {}


static func _leer_targets(drag_block: Dictionary, fallback_target: Dictionary) -> Array[Dictionary]:
	var clean_targets: Array[Dictionary] = []
	var raw_targets: Variant = drag_block.get("targets", [])
	if raw_targets is Array:
		for raw_target in raw_targets:
			var target: Dictionary = _leer_diccionario(raw_target)
			if target.is_empty():
				continue
			clean_targets.append({
				"id": str(target.get("id", "")).strip_edges(),
				"label": str(target.get("label", "")).strip_edges()
			})

	if not clean_targets.is_empty():
		return clean_targets

	if fallback_target.is_empty():
		return clean_targets

	clean_targets.append({
		"id": str(fallback_target.get("id", "")).strip_edges(),
		"label": str(fallback_target.get("label", "")).strip_edges()
	})
	return clean_targets


static func _leer_items_drag_drop(drag_block: Dictionary, default_target_id: String) -> Array[Dictionary]:
	var clean_items: Array[Dictionary] = []
	var raw_items: Variant = drag_block.get("items", [])
	if not raw_items is Array:
		return clean_items

	for raw_item in raw_items:
		var item: Dictionary = _leer_diccionario(raw_item)
		if item.is_empty():
			continue

		var resolved_target: String = str(item.get("correct_target", "")).strip_edges()
		if resolved_target.is_empty() and bool(item.get("is_correct", false)):
			resolved_target = default_target_id

		clean_items.append({
			"id": str(item.get("id", "")).strip_edges(),
			"label": str(item.get("label", "")).strip_edges(),
			"image": _leer_primer_texto(item, ["image", "image_path", "sprite"]),
			"correct_target": resolved_target
		})

	return clean_items


static func _limpiar_targets(raw_targets: Variant) -> Array[Dictionary]:
	var clean_targets: Array[Dictionary] = []
	if not raw_targets is Array:
		return clean_targets

	for raw_target in raw_targets:
		var target: Dictionary = _leer_diccionario(raw_target)
		if target.is_empty():
			continue
		clean_targets.append({
			"id": str(target.get("id", "")).strip_edges(),
			"label": str(target.get("label", "")).strip_edges()
		})

	return clean_targets


static func _limpiar_items_drag_drop(raw_items: Variant) -> Array[Dictionary]:
	var clean_items: Array[Dictionary] = []
	if not raw_items is Array:
		return clean_items

	for raw_item in raw_items:
		var item: Dictionary = _leer_diccionario(raw_item)
		if item.is_empty():
			continue
		clean_items.append({
			"id": str(item.get("id", "")).strip_edges(),
			"label": str(item.get("label", "")).strip_edges(),
			"image": str(item.get("image", "")).strip_edges(),
			"correct_target": str(item.get("correct_target", "")).strip_edges()
		})

	return clean_items


static func _leer_opciones_incorrectas(question_block: Dictionary) -> Array[String]:
	var wrong_options: Array[String] = _limpiar_array_de_textos(
		question_block.get(
			"wrong_options",
			question_block.get("wrong_answers", question_block.get("opciones_incorrectas", []))
		)
	)
	if not wrong_options.is_empty():
		return wrong_options

	var correct_answer: String = _leer_primer_texto(
		question_block,
		["correct_answer", "correct_option", "respuesta_correcta", "correct"]
	)
	var options: Array[String] = _limpiar_array_de_textos(
		question_block.get("options", question_block.get("opciones", question_block.get("choices", [])))
	)
	for option in options:
		if option != correct_answer:
			wrong_options.append(option)
	return wrong_options


static func _leer_recurso_visual(question_block: Dictionary) -> String:
	var assets: Dictionary = _leer_diccionario(question_block.get("assets", {}))
	var nested_image: String = str(assets.get("image_path", "")).strip_edges()
	if not nested_image.is_empty():
		return nested_image
	return _leer_primer_texto(question_block, ["visual_resource", "image_path", "imagen_path"])


static func _leer_primer_texto(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		if not source.has(key):
			continue
		var value: String = str(source.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


static func _normalizar_modo(raw_mode: String) -> String:
	var clean_mode: String = raw_mode.strip_edges()
	if clean_mode.is_empty():
		return MODE_QUIZ_CHOICE
	if clean_mode == "select_option":
		return MODE_QUIZ_CHOICE
	if clean_mode == "drag_to_target":
		return MODE_DRAG_DROP
	return clean_mode


static func _normalizar_dificultad(raw_difficulty: String) -> String:
	var clean_difficulty: String = raw_difficulty.strip_edges().to_lower()
	match clean_difficulty:
		"basica", "basic", "easy":
			return "easy"
		"media", "medium":
			return "medium"
		"avanzada", "advanced", "hard":
			return "hard"
		_:
			return clean_difficulty


static func _limpiar_array_de_textos(raw_values: Variant) -> Array[String]:
	var clean_values: Array[String] = []
	if not raw_values is Array:
		return clean_values

	for raw_value in raw_values:
		var clean_value: String = str(raw_value).strip_edges()
		if clean_value.is_empty():
			continue
		if clean_values.has(clean_value):
			continue
		clean_values.append(clean_value)

	return clean_values


static func _resultado_ok(data: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error": ""
	}


static func _resultado_error(message: String) -> Dictionary:
	push_error("NodeContentLoader: %s" % message)
	return {
		"ok": false,
		"data": {},
		"error": message
	}
