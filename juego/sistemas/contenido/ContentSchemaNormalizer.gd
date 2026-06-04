extends RefCounted
class_name ContentSchemaNormalizer

const DEFAULT_DRAG_ACTION := "Prepará"
const DEFAULT_DRAG_CONNECTOR := "para tu amigue"
const DEFAULT_CELIAQUIA_RESTRICTION := "celiaquía"
const DEFAULT_DRAG_MEAL := "un plato sin TACC"
const DEFAULT_WORD_SCREEN_TITLE := "Escogé la palabra que falta"
const WORD_MODE := "completar_palabra"
const BLANK := "____"


static func normalizar_word_game(id: String, raw: Dictionary) -> Dictionary:
	return normalizar_complete_word_game(id, raw)


static func normalizar_complete_word_game(id: String, raw: Dictionary) -> Dictionary:
	var clean_id: String = id.strip_edges()
	if clean_id.is_empty():
		clean_id = str(raw.get("id", "")).strip_edges()
	var prompt: String = str(raw.get("prompt", raw.get("sentence", ""))).strip_edges()
	var screen_title: String = str(
		raw.get("screen_title", DEFAULT_WORD_SCREEN_TITLE)
	).strip_edges()
	if screen_title.is_empty():
		screen_title = DEFAULT_WORD_SCREEN_TITLE
	var correct_answers: Array[String] = _as_string_array(
		raw.get("correct_answers", raw.get("answers", []))
	)
	var choices: Array[String] = _as_string_array(raw.get("choices", raw.get("options", [])))
	return {
		"id": clean_id,
		"mode": str(raw.get("mode", WORD_MODE)).strip_edges(),
		"difficulty": int(raw.get("difficulty", raw.get("dificultad", 1))),
		"screen_title": screen_title,
		"prompt": prompt,
		"sentence": prompt,
		"correct_answers": correct_answers,
		"answers": correct_answers,
		"choices": choices,
		"options": choices,
		"order_matters": bool(raw.get("order_matters", false)),
		"teaching_key": str(raw.get("teaching_key", "")).strip_edges(),
	}


static func normalizar_drag_objective(
	game: Dictionary,
	track_key: String = "",
	node_key: String = ""
) -> Dictionary:
	var raw_objective: Variant = game.get("objective", {})
	var objective: Dictionary = raw_objective as Dictionary if raw_objective is Dictionary else {}
	var source: String = _build_objective_source(game, track_key, node_key)

	var action: String = _first_text([
		objective.get("action", ""),
		objective.get("label", ""),
		game.get("action", ""),
		game.get("objective_action", ""),
		game.get("objective_label", ""),
		game.get("label", ""),
	])
	var meal: String = _first_text([
		objective.get("meal", ""),
		objective.get("main", ""),
		game.get("meal", ""),
		game.get("objective_meal", ""),
		game.get("objective_main", ""),
	])
	var connector: String = _first_text([
		objective.get("connector", ""),
		objective.get("sub", ""),
		game.get("connector", ""),
		game.get("objective_connector", ""),
		game.get("objective_sub", ""),
	])
	var restriction: String = _first_text([
		objective.get("restriction", ""),
		game.get("objective_restriction", ""),
		game.get("restriction", ""),
	])

	if meal.is_empty() or connector.is_empty():
		var message_lines: PackedStringArray = _leer_objective_message_lines(game, objective)
		if meal.is_empty() and message_lines.size() > 0:
			meal = str(message_lines[0]).strip_edges()
		if connector.is_empty() and message_lines.size() > 1:
			connector = str(message_lines[1]).strip_edges()

	if action.is_empty():
		action = DEFAULT_DRAG_ACTION
	if meal.is_empty():
		meal = _meal_from_source(source)
	if connector.is_empty():
		connector = DEFAULT_DRAG_CONNECTOR
	if restriction.is_empty() and _is_celiaquia_source(source, track_key, game):
		restriction = DEFAULT_CELIAQUIA_RESTRICTION

	return {
		"action": action,
		"meal": meal,
		"connector": connector,
		"restriction": restriction,
	}


static func drag_objective_is_complete(objective: Dictionary) -> bool:
	return (
		not str(objective.get("action", "")).strip_edges().is_empty()
		and not str(objective.get("meal", "")).strip_edges().is_empty()
		and not str(objective.get("connector", "")).strip_edges().is_empty()
	)


static func count_blanks(text: String) -> int:
	var count: int = 0
	var search_start: int = 0
	while true:
		var idx: int = text.find(BLANK, search_start)
		if idx == -1:
			break
		count += 1
		search_start = idx + BLANK.length()
	return count


static func has_all_answers_in_choices(answers: Array, choices: Array) -> bool:
	for answer in answers:
		if not choices.has(answer):
			return false
	return true


static func _as_string_array(raw_value: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_value is Array:
		return values
	for raw_entry in (raw_value as Array):
		var value: String = str(raw_entry).strip_edges()
		if value.is_empty():
			continue
		values.append(value)
	return values


static func _first_text(values: Array) -> String:
	for raw_value in values:
		var value: String = str(raw_value).strip_edges()
		if not value.is_empty():
			return value
	return ""


static func _leer_objective_message_lines(
	game: Dictionary,
	objective: Dictionary
) -> PackedStringArray:
	var message: String = _first_text([
		game.get("objective_message", ""),
		game.get("message", ""),
		objective.get("message", ""),
	])
	if message.is_empty():
		return PackedStringArray()
	return message.split("\n", false)


static func _build_objective_source(
	game: Dictionary,
	track_key: String,
	node_key: String
) -> String:
	var parts: Array[String] = [
		track_key,
		node_key,
		str(game.get("track_key", "")),
		str(game.get("node_key", "")),
		str(game.get("clave_nodo_de_origen", "")),
		str(game.get("activity_id", "")),
		str(game.get("teaching_key", "")),
		str(game.get("pack_id", "")),
	]
	return " ".join(parts).to_lower()


static func _meal_from_source(source: String) -> String:
	if source.contains("desayuno"):
		return "un desayuno sin TACC"
	if source.contains("colacion") or source.contains("colación"):
		return "una colación sin TACC"
	if source.contains("merienda"):
		return "una merienda sin TACC"
	if source.contains("almuerzo"):
		return "un almuerzo sin TACC"
	if source.contains("cena"):
		return "una cena sin TACC"
	if source.contains("bebida"):
		return "una bebida sin TACC"
	return DEFAULT_DRAG_MEAL


static func _is_celiaquia_source(source: String, track_key: String, game: Dictionary) -> bool:
	if track_key.strip_edges().to_lower() == "celiaquia":
		return true
	if str(game.get("track_key", "")).strip_edges().to_lower() == "celiaquia":
		return true
	if str(game.get("pack_id", "")).strip_edges().to_lower() == "celiaquia":
		return true
	return source.contains("celiaquia")
