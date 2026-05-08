extends RefCounted
class_name ContentNormalizer

const AdaptadorContenidoViejoScript := preload(
	"res://sistemas/contenido/AdaptadorContenidoViejo.gd"
)


static func normalize(raw_data: Dictionary, source_path: String = "") -> Dictionary:
	if is_v1_content(raw_data):
		return _ok(_normalize_v1(raw_data, source_path))
	return _ok(AdaptadorContenidoViejoScript.adaptar(raw_data))


static func is_v1_content(raw_data: Dictionary) -> bool:
	return not _infer_content_type(raw_data).is_empty()


static func _normalize_v1(raw_data: Dictionary, source_path: String = "") -> Dictionary:
	var normalized: Dictionary = raw_data.duplicate(true)
	normalized["version"] = int(raw_data.get("version", 1))
	normalized["id"] = _first_text(raw_data, ["id"])
	normalized["tipo"] = _normalize_content_type(
		_infer_content_type(raw_data).to_lower()
	)
	normalized["titulo"] = _first_text(raw_data, ["titulo", "title", "nombre"])
	normalized["descripcion"] = _first_text(
		raw_data,
		["descripcion", "description", "detalle"]
	)

	match str(normalized.get("tipo", "")):
		"assets_catalog":
			normalized["items"] = raw_data.get("items", {})
		"mapa":
			normalized["categoria"] = _first_text(
				raw_data,
				["categoria", "track_key", "id"]
			)
			normalized["nodos"] = _normalize_map_nodes(
				raw_data.get("nodos", raw_data.get("nodes", []))
			)
			normalized["track_key"] = normalized["categoria"]
		"nodo":
			normalized["categoria"] = _first_text(raw_data, ["categoria", "track_key"])
			normalized["dificultad"] = int(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalized["juegos"] = _normalize_node_games(
				raw_data.get("juegos", raw_data.get("games", []))
			)
			normalized["recompensa"] = _normalize_reward(raw_data.get("recompensa", {}))
			# Compatibilidad temporal: lectores legacy todavia buscan estas claves.
			normalized["node_key"] = normalized["id"]
			normalized["title"] = normalized["titulo"]
			normalized["difficulty"] = normalized["dificultad"]
			if not (normalized["juegos"] as Array).is_empty():
				var primer_juego: Dictionary = (normalized["juegos"] as Array)[0] as Dictionary
				normalized["mode"] = str(primer_juego.get("mode", "")).strip_edges()
				normalized["json_path"] = str(primer_juego.get("json_path", "")).strip_edges()
		"receta_arrastre":
			normalized["categoria"] = _read_content_category(raw_data, source_path)
			normalized["dificultad"] = int(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalized["objetivo"] = _first_text(
				raw_data,
				["objetivo", "consigna", "goal", "instruction"]
			)
			normalized["correctos"] = _normalize_id_array(
				raw_data.get(
					"correctos",
					raw_data.get("items_correctos", raw_data.get("itemsCorrectos", []))
				)
			)
			normalized["incorrectos"] = _normalize_id_array(
				raw_data.get(
					"incorrectos",
					raw_data.get("items_incorrectos", raw_data.get("itemsIncorrectos", []))
				)
			)
			normalized["items_correctos"] = normalized["correctos"]
			normalized["items_incorrectos"] = normalized["incorrectos"]
			normalized["cantidad_correctos"] = int(
				raw_data.get("cantidad_correctos", raw_data.get("cantidadCorrectos", 0))
			)
			normalized["cantidad_incorrectos"] = int(
				raw_data.get("cantidad_incorrectos", raw_data.get("cantidadIncorrectos", 0))
			)
			normalized["feedback"] = _normalize_feedback(raw_data.get("feedback", {}))
			normalized["teaching_key"] = _first_text(
				raw_data,
				["teaching_key", "teachingKey", "clave_ensenanza", "ensenanza"]
			)
			normalized["label_objetivo"] = _first_text(
				raw_data,
				["label_objetivo", "plato", "target_label", "targetLabel"]
			)
			normalized["mostrar_ayuda_visual"] = bool(
				raw_data.get("mostrar_ayuda_visual", raw_data.get("show_visual_help", false))
			)
			# Compatibilidad temporal con el runtime legacy.
			normalized["mode"] = "drag_drop"
			normalized["json_path"] = source_path.strip_edges()
			normalized["title"] = normalized["titulo"]
			normalized["difficulty"] = normalized["dificultad"]
		"vinculacion":
			normalized["categoria"] = _read_content_category(raw_data, source_path)
			normalized["dificultad"] = int(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalized["instruccion"] = _first_text(
				raw_data,
				["instruccion", "consigna", "instruction"]
			)
			normalized["teaching_key"] = _first_text(
				raw_data,
				["teaching_key", "teachingKey", "clave_ensenanza", "ensenanza"]
			)
			normalized["conceptos_izquierda"] = _normalize_link_concepts(
				raw_data.get("conceptos_izquierda", raw_data.get("left_concepts", []))
			)
			normalized["conceptos_derecha"] = _normalize_link_concepts(
				raw_data.get("conceptos_derecha", raw_data.get("right_concepts", []))
			)
			normalized["mode"] = "vinculacion_conceptos"
			normalized["json_path"] = source_path.strip_edges()
			normalized["title"] = normalized["titulo"]
			normalized["difficulty"] = normalized["dificultad"]
		"preguntas":
			normalized["categoria"] = _read_content_category(raw_data, source_path)
			normalized["dificultad"] = int(
				raw_data.get("dificultad", raw_data.get("difficulty", 1))
			)
			normalized["preguntas"] = _normalize_questions(
				raw_data.get("preguntas", raw_data.get("questions", []))
			)
			# Compatibilidad temporal con el runtime legacy.
			normalized["mode"] = "quiz_choice"
			normalized["json_path"] = source_path.strip_edges()
			normalized["title"] = normalized["titulo"]
			normalized["difficulty"] = normalized["dificultad"]
		"receta":
			normalized["categoria"] = _first_text(raw_data, ["categoria", "tema"])
			normalized["ingredientes"] = _normalize_id_array(
				raw_data.get("ingredientes", raw_data.get("ingredients", []))
			)
			normalized["pasos"] = _normalize_id_array(
				raw_data.get("pasos", raw_data.get("steps", []))
			)
			normalized["aprendizaje"] = _first_text(raw_data, ["aprendizaje", "learning"])

	return normalized


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
	if raw_data.has("conceptos_izquierda") or raw_data.has("left_concepts"):
		return "vinculacion"
	if raw_data.has("correctos") or raw_data.has("incorrectos"):
		return "receta_arrastre"
	if raw_data.has("items_correctos") or raw_data.has("items_incorrectos"):
		return "receta_arrastre"
	if raw_data.has("ingredientes") or raw_data.has("ingredients"):
		return "receta"
	return ""


static func _normalize_content_type(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"arrastre", "receta_arrastre", "drag_drop":
			return "receta_arrastre"
		"preguntas", "quiz_choice":
			return "preguntas"
		"vinculacion", "vinculacion_conceptos":
			return "vinculacion"
		_:
			return raw_type.strip_edges().to_lower()


static func _read_content_category(raw_data: Dictionary, source_path: String) -> String:
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


static func _normalize_map_nodes(raw_nodes: Variant) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	if not raw_nodes is Array:
		return nodes
	for raw_node in raw_nodes:
		if not raw_node is Dictionary:
			continue
		var node: Dictionary = raw_node as Dictionary
		nodes.append(
			{
				"id": _first_text(node, ["id", "node_key"]),
				"node_key": _first_text(node, ["id", "node_key"]),
				"archivo": _first_text(node, ["archivo", "file", "path"]),
				"json_path": _first_text(node, ["archivo", "file", "path"]),
				"posicion": _normalize_position(node.get("posicion", node.get("position", {}))),
				"desbloqueado_por_defecto": bool(
					node.get(
						"desbloqueado_por_defecto",
						node.get("default_unlocked", false)
					)
				),
			}
		)
	return nodes


static func _normalize_node_games(raw_games: Variant) -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	if not raw_games is Array:
		return games
	for raw_game in raw_games:
		if not raw_game is Dictionary:
			continue
		var game: Dictionary = raw_game as Dictionary
		var tipo_normalizado: String = _normalize_content_type(
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


static func _normalize_reward(raw_reward: Variant) -> Dictionary:
	if not raw_reward is Dictionary:
		return {}
	var reward: Dictionary = raw_reward as Dictionary
	return {
		"xp": int(reward.get("xp", 0)),
		"desbloquea": _normalize_id_array(reward.get("desbloquea", reward.get("unlocks", []))),
	}


static func _normalize_questions(raw_questions: Variant) -> Array[Dictionary]:
	var questions: Array[Dictionary] = []
	if not raw_questions is Array:
		return questions
	for raw_question in raw_questions:
		if not raw_question is Dictionary:
			continue
		var question: Dictionary = raw_question as Dictionary
		questions.append(
			{
				"id": _first_text(question, ["id"]),
				"enunciado": _first_text(question, ["enunciado", "question", "prompt"]),
				"opciones": _normalize_options(
					question.get("opciones", question.get("options", []))
				),
				"explicacion": _first_text(question, ["explicacion", "explanation"]),
			}
		)
	return questions


static func _normalize_options(raw_options: Variant) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if not raw_options is Array:
		return options
	for raw_option in raw_options:
		if not raw_option is Dictionary:
			continue
		var option: Dictionary = raw_option as Dictionary
		options.append(
			{
				"id": _first_text(option, ["id"]),
				"texto": _first_text(option, ["texto", "text", "label"]),
				"correcta": bool(option.get("correcta", option.get("correct", false))),
			}
		)
	return options


static func _normalize_link_concepts(raw_concepts: Variant) -> Array[Dictionary]:
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


static func _normalize_feedback(raw_feedback: Variant) -> Dictionary:
	if not raw_feedback is Dictionary:
		return {}
	var feedback: Dictionary = raw_feedback as Dictionary
	return {
		"acierto": _first_text(feedback, ["acierto", "success"]),
		"error": _first_text(feedback, ["error", "failure"]),
		"completado": _first_text(feedback, ["completado", "completed"]),
	}


static func _normalize_position(raw_position: Variant) -> Dictionary:
	if not raw_position is Dictionary:
		return {}
	var position: Dictionary = raw_position as Dictionary
	return {
		"x": float(position.get("x", 0.0)),
		"y": float(position.get("y", 0.0)),
	}


static func _normalize_id_array(raw_items: Variant) -> Array[String]:
	var items: Array[String] = []
	if not raw_items is Array:
		return items
	for raw_item in raw_items:
		var item: String = str(raw_item).strip_edges()
		if item.is_empty():
			continue
		items.append(item)
	return items


static func _first_text(source: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		var value: String = str(source.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


static func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}
