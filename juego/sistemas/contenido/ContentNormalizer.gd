extends RefCounted
class_name ContentNormalizer

# LEGACY_COMPAT: Usado por CargadorDeMapa, CargadorDeContenidoDeNodo,
# ContentValidator, GameContentFactory. No agregar lógica nueva aquí.

const AdaptadorContenidoViejoScript := preload(
	"res://sistemas/contenido/AdaptadorContenidoViejo.gd"
)


static func normalizar(raw_data: Dictionary, source_path: String = "") -> Dictionary:
	if bool(raw_data.get("__normalizado_v1", false)):
		return _ok(raw_data.duplicate(true))
	if es_contenido_v1(raw_data):
		return _ok(_normalizar_v1(raw_data, source_path))
	return _ok(AdaptadorContenidoViejoScript.adaptar(raw_data))


static func es_contenido_v1(raw_data: Dictionary) -> bool:
	return not _infer_content_type(raw_data).is_empty()


static func _normalizar_v1(raw_data: Dictionary, source_path: String = "") -> Dictionary:
	var normalizado: Dictionary = raw_data.duplicate(true)
	normalizado["__normalizado_v1"] = true
	normalizado["version"] = int(raw_data.get("version", 1))
	normalizado["id"] = _first_text(raw_data, ["id"])
	normalizado["tipo"] = _normalizar_content_type(
		_infer_content_type(raw_data).to_lower()
	)
	normalizado["titulo"] = _first_text(raw_data, ["titulo", "title", "nombre"])
	normalizado["descripcion"] = _first_text(
		raw_data,
		["descripcion", "description", "detalle"]
	)

	match str(normalizado.get("tipo", "")):
		"assets_catalog":
			normalizado["items"] = raw_data.get("items", {})
		"mapa":
			normalizado["categoria"] = _first_text(
				raw_data,
				["categoria", "track_key", "id"]
			)
			normalizado["nodos"] = _normalizar_map_nodes(
				raw_data.get("nodos", raw_data.get("nodes", []))
			)
			normalizado["track_key"] = normalizado["categoria"]
		"nodo":
			normalizado["categoria"] = _first_text(raw_data, ["categoria", "track_key"])
			normalizado["dificultad"] = int(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalizado["juegos"] = _normalizar_node_games(
				raw_data.get("juegos", raw_data.get("games", []))
			)
			normalizado["recompensa"] = _normalizar_reward(raw_data.get("recompensa", {}))
			# Compatibilidad temporal: lectores legacy todavia buscan estas claves.
			normalizado["node_key"] = normalizado["id"]
			normalizado["title"] = normalizado["titulo"]
			normalizado["difficulty"] = normalizado["dificultad"]
			if not (normalizado["juegos"] as Array).is_empty():
				var primer_juego: Dictionary = (normalizado["juegos"] as Array)[0] as Dictionary
				normalizado["mode"] = str(primer_juego.get("mode", "")).strip_edges()
				normalizado["json_path"] = str(primer_juego.get("json_path", "")).strip_edges()
		"receta_arrastre":
			normalizado["categoria"] = _leer_content_category(raw_data, source_path)
			normalizado["dificultad"] = _normalizar_difficulty_value(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalizado["tiene_dificultad_explicita"] = (
				raw_data.has("dificultad") or raw_data.has("difficulty")
			)
			normalizado["objetivo"] = _first_text(
				raw_data,
				["objetivo", "consigna", "goal", "instruction"]
			)
			normalizado["correctos"] = _normalizar_id_array(
				raw_data.get(
					"correctos",
					raw_data.get("items_correctos", raw_data.get("itemsCorrectos", []))
				)
			)
			normalizado["incorrectos"] = _normalizar_id_array(
				raw_data.get(
					"incorrectos",
					raw_data.get("items_incorrectos", raw_data.get("itemsIncorrectos", []))
				)
			)
			normalizado["items_correctos"] = normalizado["correctos"]
			normalizado["items_incorrectos"] = normalizado["incorrectos"]
			normalizado["cantidad_correctos"] = int(
				raw_data.get("cantidad_correctos", raw_data.get("cantidadCorrectos", 0))
			)
			normalizado["cantidad_incorrectos"] = int(
				raw_data.get("cantidad_incorrectos", raw_data.get("cantidadIncorrectos", 0))
			)
			normalizado["feedback"] = _normalizar_feedback(raw_data.get("feedback", {}))
			normalizado["teaching_key"] = _first_text(
				raw_data,
				["teaching_key", "teachingKey", "clave_ensenanza", "ensenanza"]
			)
			normalizado["label_objetivo"] = _first_text(
				raw_data,
				["label_objetivo", "plato", "target_label", "targetLabel"]
			)
			normalizado["mostrar_ayuda_visual"] = bool(
				raw_data.get("mostrar_ayuda_visual", raw_data.get("show_visual_help", false))
			)
			# Compatibilidad temporal con el runtime legacy.
			normalizado["mode"] = "drag_drop"
			normalizado["json_path"] = source_path.strip_edges()
			normalizado["title"] = normalizado["titulo"]
			normalizado["difficulty"] = normalizado["dificultad"]
		"vinculacion":
			normalizado["categoria"] = _leer_content_category(raw_data, source_path)
			normalizado["dificultad"] = _normalizar_difficulty_value(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalizado["tiene_dificultad_explicita"] = (
				raw_data.has("dificultad") or raw_data.has("difficulty")
			)
			normalizado["usa_formato_simple_vinculacion"] = _is_simple_linking_format(raw_data)
			normalizado["instruccion"] = _first_text(
				raw_data,
				["instruccion", "consigna", "instruction"]
			)
			normalizado["teaching_key"] = _first_text(
				raw_data,
				["teaching_key", "teachingKey", "clave_ensenanza", "ensenanza"]
			)
			normalizado["pares"] = _normalizar_link_pairs(raw_data.get("pares", []))
			normalizado["distractores"] = _normalizar_text_array(
				raw_data.get("distractores", [])
			)
			var linked_concepts: Dictionary = _normalizar_link_content(
				normalizado.get("pares", []),
				normalizado.get("distractores", []),
				raw_data.get("conceptos_izquierda", raw_data.get("left_concepts", [])),
				raw_data.get("conceptos_derecha", raw_data.get("right_concepts", []))
			)
			normalizado["conceptos_izquierda"] = linked_concepts.get(
				"conceptos_izquierda",
				[]
			)
			normalizado["conceptos_derecha"] = linked_concepts.get(
				"conceptos_derecha",
				[]
			)
			normalizado["mode"] = "vinculacion_conceptos"
			normalizado["json_path"] = source_path.strip_edges()
			normalizado["title"] = normalizado["titulo"]
			normalizado["difficulty"] = normalizado["dificultad"]
		"preguntas":
			normalizado["categoria"] = _leer_content_category(raw_data, source_path)
			normalizado["dificultad"] = _normalizar_difficulty_value(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalizado["tiene_dificultad_explicita"] = (
				raw_data.has("dificultad") or raw_data.has("difficulty")
			)
			normalizado["usa_formato_simple_preguntas"] = _is_simple_questions_format(
				raw_data,
				raw_data.get("preguntas", raw_data.get("questions", []))
			)
			normalizado["consigna"] = _first_text(
				raw_data,
				["consigna", "instruction", "objetivo"]
			)
			normalizado["teaching_key"] = _first_text(
				raw_data,
				["teaching_key", "teachingKey", "clave_ensenanza", "ensenanza"]
			)
			normalizado["preguntas"] = _normalizar_questions(
				raw_data.get("preguntas", raw_data.get("questions", []))
			)
			# Compatibilidad temporal con el runtime legacy.
			normalizado["mode"] = "quiz_choice"
			normalizado["json_path"] = source_path.strip_edges()
			normalizado["title"] = normalizado["titulo"]
			normalizado["difficulty"] = normalizado["dificultad"]
		"receta":
			normalizado["categoria"] = _first_text(raw_data, ["categoria", "tema"])
			normalizado["ingredientes"] = _normalizar_id_array(
				raw_data.get("ingredientes", raw_data.get("ingredients", []))
			)
			normalizado["pasos"] = _normalizar_id_array(
				raw_data.get("pasos", raw_data.get("steps", []))
			)
			normalizado["aprendizaje"] = _first_text(raw_data, ["aprendizaje", "learning"])

	return normalizado


static func _infer_content_type(raw_data: Dictionary) -> String:
	if raw_data.is_empty():
		return ""
	var explicit_type: String = _first_text(raw_data, ["tipo", "type"])
	if not explicit_type.is_empty():
		return explicit_type
	if raw_data.has("nodos"):
		return "mapa"
	if raw_data.has("juegos"):
		return "nodo"
	if raw_data.has("preguntas") or raw_data.has("questions"):
		return "preguntas"
	if raw_data.has("pares"):
		return "vinculacion"
	if raw_data.has("conceptos_izquierda") or raw_data.has("left_concepts"):
		return "vinculacion"
	if raw_data.has("correctos") or raw_data.has("incorrectos"):
		return "receta_arrastre"
	if raw_data.has("items_correctos") or raw_data.has("items_incorrectos"):
		return "receta_arrastre"
	if raw_data.has("ingredientes") or raw_data.has("ingredients"):
		return "receta"
	return ""


static func _normalizar_content_type(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"arrastre", "receta_arrastre", "drag_drop":
			return "receta_arrastre"
		"preguntas", "quiz_choice":
			return "preguntas"
		"vinculacion", "vinculacion_conceptos":
			return "vinculacion"
		_:
			return raw_type.strip_edges().to_lower()


static func _leer_content_category(raw_data: Dictionary, source_path: String) -> String:
	var explicit_category: String = _first_text(raw_data, ["categoria", "tema", "track_key"])
	if not explicit_category.is_empty():
		return explicit_category
	return _infer_category_from_source_path(source_path)


static func _infer_category_from_source_path(source_path: String) -> String:
	var clean_path: String = source_path.strip_edges()
	if clean_path.is_empty():
		return ""
	var path_parts: PackedStringArray = clean_path.split("/", false)
	var nodes_index: int = path_parts.find("nodos")
	if nodes_index >= 0 and nodes_index + 1 < path_parts.size():
		return path_parts[nodes_index + 1].strip_edges()
	return ""


static func _normalizar_map_nodes(raw_nodes: Variant) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if not raw_nodes is Array:
		return nodes
	for raw_node in raw_nodes:
		if raw_node is String:
			var node_path: String = str(raw_node).strip_edges()
			nodes.append(
				{
					"id": _infer_id_from_path(node_path),
					"node_key": _infer_id_from_path(node_path),
					"archivo": node_path,
					"json_path": node_path,
					"posicion": {},
					"desbloqueado_por_defecto": false,
				}
			)
			continue
		if not raw_node is Dictionary:
			continue
		var node: Dictionary = raw_node as Dictionary
		var file_path: String = _first_text(node, ["archivo", "file", "path"])
		var normalizado_id: String = _first_text(node, ["id", "node_key"])
		if normalizado_id.is_empty():
			normalizado_id = _infer_id_from_path(file_path)
		nodes.append(
			{
				"id": normalizado_id,
				"node_key": normalizado_id,
				"archivo": file_path,
				"json_path": file_path,
				"posicion": _normalizar_position(node.get("posicion", node.get("position", {}))),
				"desbloqueado_por_defecto": bool(
					node.get(
						"desbloqueado_por_defecto",
						node.get("default_unlocked", false)
					)
				),
			}
		)
	return nodes


static func _infer_id_from_path(raw_path: String) -> String:
	var clean_path: String = raw_path.strip_edges()
	if clean_path.is_empty():
		return ""
	return clean_path.get_file().trim_suffix(".json")


static func _normalizar_node_games(raw_games: Variant) -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	if not raw_games is Array:
		return games
	for raw_game in raw_games:
		if not raw_game is Dictionary:
			continue
		var game: Dictionary = raw_game as Dictionary
		var tipo_normalizado: String = _normalizar_content_type(
			_first_text(game, ["tipo", "type"])
		)
		var modo_legacy: String = _map_v1_game_type_to_mode(tipo_normalizado)
		var ruta_archivo: String = _first_text(game, ["archivo", "file", "path"])
		games.append(
			{
				"id": _first_text(game, ["id"]),
				"tipo": tipo_normalizado,
				"mode": modo_legacy,
				"archivo": ruta_archivo,
				"json_path": ruta_archivo,
				"titulo": _first_text(game, ["titulo", "title"]),
				"title": _first_text(game, ["titulo", "title"]),
			}
		)
	return games


static func _map_v1_game_type_to_mode(game_type: String) -> String:
	match game_type.strip_edges().to_lower():
		"receta_arrastre", "arrastre", "drag_drop":
			return "drag_drop"
		"preguntas", "quiz_choice":
			return "quiz_choice"
		"vinculacion", "vinculacion_conceptos":
			return "vinculacion_conceptos"
		_:
			return ""


static func _normalizar_reward(raw_reward: Variant) -> Dictionary:
	if not raw_reward is Dictionary:
		return {}
	var reward: Dictionary = raw_reward as Dictionary
	return {
		"xp": int(reward.get("xp", 0)),
		"desbloquea": _normalizar_id_array(reward.get("desbloquea", reward.get("unlocks", []))),
	}


static func _normalizar_questions(raw_questions: Variant) -> Array[Dictionary]:
	var questions: Array[Dictionary] = []
	if not raw_questions is Array:
		return questions
	for index in range((raw_questions as Array).size()):
		var raw_question: Variant = (raw_questions as Array)[index]
		if not raw_question is Dictionary:
			continue
		var question: Dictionary = raw_question as Dictionary
		var question_id: String = _first_text(question, ["id"])
		if question_id.is_empty():
			question_id = "pregunta_%d" % (index + 1)
		var correct_answer: String = _first_text(
			question,
			["respuesta", "correct_answer", "answer"]
		)
		var normalizado_options: Array[Dictionary] = _normalizar_options(
			question.get(
				"opciones",
				question.get("options", _build_options_from_runtime_question(question))
			),
			correct_answer
		)
		questions.append(
			{
				"id": question_id,
				"enunciado": _first_text(
					question,
					["texto", "enunciado", "question", "prompt"]
				),
				"respuesta": correct_answer,
				"opciones": normalizado_options,
				"explicacion": _first_text(question, ["explicacion", "explanation"]),
			}
		)
	return questions


static func _normalizar_options(
	raw_options: Variant,
	correct_answer: String = ""
) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not raw_options is Array:
		return options
	for index in range((raw_options as Array).size()):
		var raw_option: Variant = (raw_options as Array)[index]
		if raw_option is String:
			var option_text: String = str(raw_option).strip_edges()
			if option_text.is_empty():
				continue
			options.append(
				{
					"id": "opcion_%d" % (index + 1),
					"texto": option_text,
					"correcta": option_text == correct_answer,
				}
			)
			continue
		if not raw_option is Dictionary:
			continue
		var option: Dictionary = raw_option as Dictionary
		var option_id: String = _first_text(option, ["id"])
		if option_id.is_empty():
			option_id = "opcion_%d" % (index + 1)
		options.append(
			{
				"id": option_id,
				"texto": _first_text(option, ["texto", "text", "label"]),
				"correcta": bool(option.get("correcta", option.get("correct", false))),
			}
		)
	return options


static func _build_options_from_runtime_question(question: Dictionary) -> Array[String]:
	var options: Array[String] = []
	var correct_answer: String = _first_text(
		question,
		["respuesta", "correct_answer", "answer"]
	)
	if not correct_answer.is_empty():
		options.append(correct_answer)
	for raw_wrong_option in question.get("wrong_options", []):
		var wrong_option: String = str(raw_wrong_option).strip_edges()
		if wrong_option.is_empty() or options.has(wrong_option):
			continue
		options.append(wrong_option)
	return options


static func _normalizar_link_concepts(raw_concepts: Variant) -> Array[Dictionary]:
	var concepts: Array[Dictionary] = []
	if not raw_concepts is Array:
		return concepts
	for raw_concept in raw_concepts:
		if not raw_concept is Dictionary:
			continue
		var concept: Dictionary = raw_concept as Dictionary
		concepts.append(
			{
				"id": _first_text(concept, ["id"]),
				"texto": _first_text(concept, ["texto", "text", "label"]),
				"id_par": _first_text(concept, ["id_par", "pair_id", "pairId"]),
			}
		)
	return concepts


static func _normalizar_link_pairs(raw_pairs: Variant) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if not raw_pairs is Array:
		return pairs
	for index in range((raw_pairs as Array).size()):
		var raw_pair: Variant = (raw_pairs as Array)[index]
		if not raw_pair is Dictionary:
			continue
		var pair: Dictionary = raw_pair as Dictionary
		var pair_id: String = _first_text(pair, ["id"])
		if pair_id.is_empty():
			pair_id = "par_%d" % (index + 1)
		pairs.append(
			{
				"id": pair_id,
				"izquierda": _first_text(pair, ["izquierda", "left"]),
				"derecha": _first_text(pair, ["derecha", "right"]),
				"explicacion": _first_text(pair, ["explicacion", "explanation"]),
			}
		)
	return pairs


static func _normalizar_link_content(
	raw_pairs: Variant,
	raw_distractors: Variant,
	raw_left_concepts: Variant,
	raw_right_concepts: Variant
) -> Dictionary:
	var pairs: Array[Dictionary] = raw_pairs if raw_pairs is Array else []
	if pairs.is_empty():
		return {
			"conceptos_izquierda": _normalizar_link_concepts(raw_left_concepts),
			"conceptos_derecha": _normalizar_link_concepts(raw_right_concepts),
		}

	var left_concepts: Array[Dictionary] = []
	var right_concepts: Array[Dictionary] = []
	for index in range(pairs.size()):
		var pair: Dictionary = pairs[index]
		var pair_id: String = str(pair.get("id", "par_%d" % (index + 1))).strip_edges()
		left_concepts.append(
			{
				"id": "izq_%s" % pair_id,
				"texto": str(pair.get("izquierda", "")).strip_edges(),
				"id_par": pair_id,
			}
		)
		right_concepts.append(
			{
				"id": "der_%s" % pair_id,
				"texto": str(pair.get("derecha", "")).strip_edges(),
				"id_par": pair_id,
			}
		)
	var distractors: Array[String] = _normalizar_text_array(raw_distractors)
	for index in range(distractors.size()):
		var distractor: String = distractors[index]
		var distractor_id: String = "distractor_%d" % (index + 1)
		right_concepts.append(
			{
				"id": distractor_id,
				"texto": distractor,
				"id_par": distractor_id,
			}
		)
	return {
		"conceptos_izquierda": left_concepts,
		"conceptos_derecha": right_concepts,
	}


static func _normalizar_feedback(raw_feedback: Variant) -> Dictionary:
	if not raw_feedback is Dictionary:
		return {}
	var feedback: Dictionary = raw_feedback as Dictionary
	return {
		"acierto": _first_text(feedback, ["acierto", "success"]),
		"error": _first_text(feedback, ["error", "failure"]),
		"completado": _first_text(feedback, ["completado", "completed"]),
	}


static func _normalizar_position(raw_position: Variant) -> Dictionary:
	if not raw_position is Dictionary:
		return {}
	var position: Dictionary = raw_position as Dictionary
	return {
		"x": float(position.get("x", 0.0)),
		"y": float(position.get("y", 0.0)),
	}


static func _normalizar_id_array(raw_items: Variant) -> Array[String]:
	var items: Array[String] = []
	if not raw_items is Array:
		return items
	for raw_item in raw_items:
		var item: String = str(raw_item).strip_edges()
		if item.is_empty():
			continue
		items.append(item)
	return items


static func _normalizar_text_array(raw_items: Variant) -> Array[String]:
	var items: Array[String] = []
	if not raw_items is Array:
		return items
	for raw_item in raw_items:
		var item: String = str(raw_item).strip_edges()
		if item.is_empty() or items.has(item):
			continue
		items.append(item)
	return items


static func _normalizar_difficulty_value(raw_difficulty: Variant) -> int:
	match typeof(raw_difficulty):
		TYPE_INT:
			return clampi(int(raw_difficulty), 1, 5)
		TYPE_FLOAT:
			return clampi(int(round(float(raw_difficulty))), 1, 5)
		_:
			var difficulty_text: String = str(raw_difficulty).strip_edges().to_lower()
			match difficulty_text:
				"easy":
					return 1
				"medium":
					return 3
				"hard":
					return 5
				_:
					if difficulty_text.is_valid_int():
						return clampi(int(difficulty_text), 1, 5)
	return 1


static func _is_simple_questions_format(raw_data: Dictionary, raw_questions: Variant) -> bool:
	if (
		raw_data.has("consigna")
		or raw_data.has("ensenanza")
		or raw_data.has("dificultad")
		or raw_data.has("difficulty")
	):
		return true
	if not raw_questions is Array:
		return false
	for raw_question in raw_questions as Array:
		if not raw_question is Dictionary:
			continue
		var question: Dictionary = raw_question as Dictionary
		if question.has("texto") or question.has("respuesta"):
			return true
	return false


static func _is_simple_linking_format(raw_data: Dictionary) -> bool:
	return (
		raw_data.has("pares")
		or raw_data.has("distractores")
		or raw_data.has("consigna")
		or raw_data.has("ensenanza")
		or raw_data.has("dificultad")
		or raw_data.has("difficulty")
	)


static func _first_text(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		var value: String = str(source.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


static func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}
