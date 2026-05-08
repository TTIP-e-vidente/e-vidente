extends RefCounted
class_name ContentValidator

const ContentCatalogScript := preload("res://sistemas/contenido/ContentCatalog.gd")
const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const ContentNormalizerScript := preload("res://sistemas/contenido/ContentNormalizer.gd")

const SUPPORTED_TYPES := [
	"assets_catalog",
	"mapa",
	"nodo",
	"receta_arrastre",
	"preguntas",
	"vinculacion",
	"receta",
]

const DEMO_PLAYABLE_TYPES := ["receta_arrastre", "preguntas", "vinculacion"]


static func validate(raw_data: Dictionary, source_path: String = "") -> Dictionary:
	var normalized_result: Dictionary = ContentNormalizerScript.normalize(raw_data, source_path)
	var normalized_data: Dictionary = normalized_result.get("data", {})
	if not ContentNormalizerScript.is_v1_content(normalized_data):
		return _ok([])

	var errors: Array[String] = _validate_common_fields(normalized_data)
	match str(normalized_data.get("tipo", "")):
		"assets_catalog":
			errors.append_array(_validate_assets_catalog(normalized_data))
		"mapa":
			errors.append_array(_validate_map(normalized_data))
		"nodo":
			errors.append_array(_validate_node(normalized_data))
		"receta_arrastre":
			errors.append_array(_validate_drag_drop_game(normalized_data))
		"preguntas":
			errors.append_array(_validate_questions_game(normalized_data))
		"vinculacion":
			errors.append_array(_validate_linking_game(normalized_data))
		"receta":
			errors.append_array(_validate_recipe(normalized_data))

	if errors.is_empty():
		return _ok([])
	return {
		"ok": false,
		"errors": errors,
		"error": format_errors(source_path, errors),
	}


static func format_errors(source_path: String, errors: Array[String]) -> String:
	var display_name: String = ContentJsonLoaderScript.display_name(source_path)
	var lines: Array[String] = ["[Contenido invalido] %s" % display_name]
	for error in errors:
		lines.append("- %s" % error)
	return "\n".join(lines)


static func _validate_common_fields(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("id", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: id")
	var tipo: String = str(data.get("tipo", "")).strip_edges()
	if tipo.is_empty():
		errors.append("Falta campo obligatorio: tipo")
	elif not SUPPORTED_TYPES.has(tipo):
		errors.append("tipo invalido: %s" % tipo)
	if str(data.get("titulo", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: titulo")
	if (
		tipo in ["nodo", "receta"]
		and str(data.get("descripcion", "")).strip_edges().is_empty()
	):
		errors.append("Falta campo obligatorio: descripcion")
	return errors


static func _validate_assets_catalog(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var items: Variant = data.get("items", {})
	if not items is Dictionary:
		errors.append("Falta campo obligatorio: items")
		return errors
	for item_id in (items as Dictionary).keys():
		var item_definition: Variant = (items as Dictionary).get(item_id, {})
		if not item_definition is Dictionary:
			errors.append("Item invalido en catalogo: %s" % item_id)
			continue
		var definition: Dictionary = item_definition as Dictionary
		if str(definition.get("nombre", "")).strip_edges().is_empty():
			errors.append("Item sin nombre en catalogo: %s" % item_id)
		var asset_path: String = ContentJsonLoaderScript.resolve_path(
			str(definition.get("resource", definition.get("asset", ""))).strip_edges()
		)
		if asset_path.is_empty() or not FileAccess.file_exists(asset_path):
			errors.append(
				"Resource no encontrado en items.json: \"%s\"" % item_id
			)
	return errors


static func _validate_map(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("categoria", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: categoria")
	var nodes: Variant = data.get("nodos", [])
	if not nodes is Array or (nodes as Array).is_empty():
		errors.append("Falta campo obligatorio: nodos")
		return errors
	for raw_node in nodes as Array:
		if raw_node is String:
			var node_path_from_string: String = _resolve_file_field(raw_node)
			var node_id_from_string: String = _infer_id_from_path(str(raw_node).strip_edges())
			if (
				node_path_from_string.is_empty()
				or not FileAccess.file_exists(node_path_from_string)
			):
				errors.append("Mapa referencia un nodo que no existe: %s" % node_id_from_string)
			continue
		if not raw_node is Dictionary:
			errors.append("Cada nodo del mapa debe ser un objeto")
			continue
		var node: Dictionary = raw_node as Dictionary
		var node_id: String = str(
			node.get("id", _infer_id_from_path(str(node.get("archivo", ""))))
		).strip_edges()
		if node_id.is_empty():
			errors.append("Nodo del mapa sin id")
		var file_path: String = _resolve_file_field(node.get("archivo", ""))
		if file_path.is_empty() or not FileAccess.file_exists(file_path):
			errors.append("Mapa referencia un nodo que no existe: %s" % node_id)
	return errors


static func _validate_node(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("categoria", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: categoria")
	var games: Variant = data.get("juegos", [])
	if not games is Array or (games as Array).is_empty():
		errors.append("Falta campo obligatorio: juegos")
		return errors
	for raw_game in games as Array:
		if not raw_game is Dictionary:
			errors.append("Cada juego del nodo debe ser un objeto")
			continue
		var game: Dictionary = raw_game as Dictionary
		var game_id: String = str(game.get("id", "")).strip_edges()
		var game_type: String = str(game.get("tipo", "")).strip_edges()
		var file_path: String = _resolve_file_field(game.get("archivo", ""))
		if game_id.is_empty():
			errors.append("Juego del nodo sin id")
		if game_type.is_empty():
			errors.append("Juego del nodo sin tipo: %s" % game_id)
		elif not DEMO_PLAYABLE_TYPES.has(game_type):
			errors.append("tipo invalido en nodo: %s" % game_type)
		if file_path.is_empty() or not FileAccess.file_exists(file_path):
			errors.append("Nodo referencia un juego que no existe: %s" % game_id)
	return errors


static func _validate_drag_drop_game(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("objetivo", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: consigna")
	if str(data.get("label_objetivo", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: plato")
	if str(data.get("teaching_key", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: ensenanza")
	var correct_items: Array[String] = data.get("correctos", data.get("items_correctos", []))
	var wrong_items: Array[String] = data.get("incorrectos", data.get("items_incorrectos", []))
	if correct_items.is_empty():
		errors.append("Falta campo obligatorio: correctos")
	if wrong_items.is_empty():
		errors.append("Falta campo obligatorio: incorrectos")
	var correct_count: int = int(data.get("cantidad_correctos", 0))
	var wrong_count: int = int(data.get("cantidad_incorrectos", 0))
	if correct_count <= 0:
		errors.append("cantidad_correctos invalida")
	if wrong_count <= 0:
		errors.append("cantidad_incorrectos invalida")
	var duplicated_items: Array[String] = _intersect_item_ids(correct_items, wrong_items)
	if not duplicated_items.is_empty():
		errors.append(
			"Item repetido entre correctos e incorrectos: %s" % ", ".join(duplicated_items)
		)
	for item_id in correct_items + wrong_items:
		var definition_result: Dictionary = ContentCatalogScript.resolve_item_definition(item_id)
		if not bool(definition_result.get("ok", false)):
			errors.append("Item no existe en items.json: %s" % item_id)
	return errors


static func _validate_linking_game(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var uses_simple_format: bool = bool(data.get("usa_formato_simple_vinculacion", false))
	if uses_simple_format and not bool(data.get("tiene_dificultad_explicita", false)):
		errors.append("Falta dificultad.")
	if uses_simple_format and str(data.get("instruccion", "")).strip_edges().is_empty():
		errors.append("Falta consigna.")
	if uses_simple_format and str(data.get("teaching_key", "")).strip_edges().is_empty():
		errors.append("Falta ensenanza.")
	var pairs: Variant = data.get("pares", [])
	if uses_simple_format and pairs is Array and (pairs as Array).is_empty():
		errors.append("En vinculacion: falta pares.")
	elif uses_simple_format and pairs is Array:
		for raw_pair in pairs as Array:
			if not raw_pair is Dictionary:
				continue
			var pair: Dictionary = raw_pair as Dictionary
			if (
				str(pair.get("izquierda", "")).strip_edges().is_empty()
				or str(pair.get("derecha", "")).strip_edges().is_empty()
			):
				errors.append("En vinculacion: par sin izquierda o derecha.")
	var conceptos_izquierda: Variant = data.get("conceptos_izquierda", [])
	var conceptos_derecha: Variant = data.get("conceptos_derecha", [])
	if not conceptos_izquierda is Array or (conceptos_izquierda as Array).size() < 2:
		errors.append("Vinculacion: se esperan al menos dos conceptos a la izquierda")
	if not conceptos_derecha is Array or (conceptos_derecha as Array).size() < 2:
		errors.append("Vinculacion: se esperan al menos dos conceptos a la derecha")
	if conceptos_izquierda is Array and conceptos_derecha is Array:
		if (conceptos_derecha as Array).size() < (conceptos_izquierda as Array).size():
			errors.append(
				"Vinculacion: faltan opciones a la derecha para todos los pares"
			)
	return errors


static func _validate_questions_game(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var uses_simple_format: bool = bool(data.get("usa_formato_simple_preguntas", false))
	if uses_simple_format and not bool(data.get("tiene_dificultad_explicita", false)):
		errors.append("Falta dificultad.")
	if uses_simple_format and str(data.get("consigna", "")).strip_edges().is_empty():
		errors.append("Falta consigna.")
	if uses_simple_format and str(data.get("teaching_key", "")).strip_edges().is_empty():
		errors.append("Falta ensenanza.")
	var questions: Variant = data.get("preguntas", [])
	if not questions is Array or (questions as Array).is_empty():
		errors.append(
			"En preguntas: falta preguntas."
			if uses_simple_format
			else "Falta campo obligatorio: preguntas"
		)
		return errors
	for raw_question in questions as Array:
		if not raw_question is Dictionary:
			errors.append("Cada pregunta debe ser un objeto")
			continue
		var question: Dictionary = raw_question as Dictionary
		if str(question.get("enunciado", "")).strip_edges().is_empty():
			errors.append(
				"En preguntas: pregunta sin texto."
				if uses_simple_format
				else "Pregunta sin enunciado"
			)
		var answer_text: String = str(question.get("respuesta", "")).strip_edges()
		if uses_simple_format and answer_text.is_empty():
			errors.append("En preguntas: pregunta sin respuesta.")
		var options: Variant = question.get("opciones", [])
		if not options is Array or (options as Array).size() < 2:
			errors.append(
				"En preguntas: pregunta con opciones insuficientes."
				if uses_simple_format
				else "Pregunta con opciones insuficientes: %s" % question.get("id", "")
			)
			continue
		var correct_option_count := 0
		var option_texts: Array[String] = []
		for raw_option in options as Array:
			if not raw_option is Dictionary:
				continue
			var option: Dictionary = raw_option as Dictionary
			var option_text: String = str(option.get("texto", "")).strip_edges()
			if not option_text.is_empty():
				option_texts.append(option_text)
			if bool(option.get("correcta", false)):
				correct_option_count += 1
		if correct_option_count != 1:
			errors.append("Cada pregunta debe tener una sola opcion correcta")
		if uses_simple_format and not answer_text.is_empty() and not option_texts.has(answer_text):
			errors.append("En preguntas: respuesta no está dentro de opciones.")
	return errors


static func _validate_recipe(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(data.get("categoria", "")).strip_edges().is_empty():
		errors.append("Falta campo obligatorio: categoria")
	var ingredients: Array[String] = data.get("ingredientes", [])
	var steps: Array[String] = data.get("pasos", [])
	if ingredients.is_empty():
		errors.append("Falta campo obligatorio: ingredientes")
	if steps.is_empty():
		errors.append("Falta campo obligatorio: pasos")
	for item_id in ingredients:
		var definition_result: Dictionary = ContentCatalogScript.resolve_item_definition(item_id)
		if not bool(definition_result.get("ok", false)):
			errors.append(str(definition_result.get("error", "Asset invalido.")))
	return errors


static func _resolve_file_field(raw_path: Variant) -> String:
	return ContentJsonLoaderScript.resolve_path(str(raw_path).strip_edges())


static func _infer_id_from_path(raw_path: String) -> String:
	var clean_path: String = raw_path.strip_edges()
	if clean_path.is_empty():
		return ""
	return clean_path.get_file().trim_suffix(".json")


static func _intersect_item_ids(left_ids: Array[String], right_ids: Array[String]) -> Array[String]:
	var left_seen: Dictionary = {}
	var duplicates: Array[String] = []
	for item_id in left_ids:
		left_seen[item_id] = true
	for item_id in right_ids:
		if left_seen.has(item_id) and not duplicates.has(item_id):
			duplicates.append(item_id)
	return duplicates


static func _ok(errors: Array[String]) -> Dictionary:
	return {"ok": true, "errors": errors, "error": ""}