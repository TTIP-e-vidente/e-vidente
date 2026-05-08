extends RefCounted
class_name MapNodeData

# Representa los datos simples de un nodo del mapa.
# Guarda games fijos, requests random y shuffle_games.
# No carga JSON, no busca activities y no abre escenas.

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"
const MODE_VINCULACION_CONCEPTOS := "vinculacion_conceptos"

var node_key: String = ""
var order: int = 0
var title: String = ""
var mode: String = ""
var json_path: String = ""
var activity_id: String = ""
var pack_id: String = ""
var track_key: String = ""
var index: int = 0
var fixed_games: Array[String] = []
var random_game_requests: Array[Dictionary] = []
var fixed_game_entries: Array[Dictionary] = []

# Alias legacy internos. El flujo nuevo usa fixed/random games.
var games: Array[String] = []
var game_slots: Array[Dictionary] = []
var difficulty: int = 0
var description: String = ""
var node_file_path: String = ""
var game_entries: Array[Dictionary] = []
var shuffle_games := false
var default_unlocked := false
var reward: Dictionary = {}
var map_position := Vector2.ZERO
var has_map_position := false

static func from_json(raw_node: Dictionary, map_track_key: String, node_index: int) -> MapNodeData:
	var node := MapNodeData.new()
	node.node_key = str(raw_node.get("node_key", "")).strip_edges()
	node.title = str(raw_node.get("title", "")).strip_edges()
	node.mode = str(raw_node.get("mode", "")).strip_edges()
	node.json_path = str(raw_node.get("json_path", "")).strip_edges()
	node.activity_id = str(raw_node.get("activity_id", "")).strip_edges()
	node.track_key = map_track_key.strip_edges()
	node.pack_id = str(raw_node.get("pack_id", node.track_key)).strip_edges()
	node.index = node_index
	node.order = node_index + 1
	node.difficulty = int(raw_node.get("difficulty", 0))
	node.shuffle_games = bool(raw_node.get("shuffle_games", false))
	var raw_games: Variant = raw_node.get("games", [])
	var raw_legacy_game_slots: Variant = raw_node.get("game_slots", [])
	node.fixed_game_entries = _normalize_fixed_game_entries(raw_games)
	node.random_game_requests = _normalize_random_game_requests(raw_games)
	if node.random_game_requests.is_empty():
		node.random_game_requests = _normalize_random_game_requests(raw_legacy_game_slots)
	if node.fixed_game_entries.is_empty() and not node.activity_id.is_empty():
		node.fixed_game_entries.append({
			"activity_id": node.activity_id,
			"pack_id": node.pack_id,
			"difficulty": node.difficulty,
			"dificultad": node.difficulty,
		})
	node.fixed_games = _extract_fixed_game_ids(node.fixed_game_entries)
	node.games = node.fixed_games
	node.game_entries = node.fixed_game_entries
	node.game_slots = node.random_game_requests
	if not node.fixed_game_entries.is_empty():
		var first_game: Dictionary = node.fixed_game_entries[0]
		if node.activity_id.is_empty():
			node.activity_id = str(first_game.get("activity_id", "")).strip_edges()
		if node.pack_id.is_empty():
			node.pack_id = str(first_game.get("pack_id", "")).strip_edges()
	if node.pack_id.is_empty():
		node.pack_id = node.track_key
	return node


static func from_v1_node(
	raw_node: Dictionary,
	map_track_key: String,
	node_index: int,
	map_entry: Dictionary = {},
	node_path: String = ""
) -> MapNodeData:
	var node := MapNodeData.new()
	node.node_key = str(raw_node.get("id", "")).strip_edges()
	node.title = str(raw_node.get("titulo", "")).strip_edges()
	node.track_key = map_track_key.strip_edges()
	node.index = node_index
	node.order = node_index + 1
	node.difficulty = int(raw_node.get("dificultad", 0))
	node.description = str(raw_node.get("descripcion", "")).strip_edges()
	node.node_file_path = node_path.strip_edges()
	node.default_unlocked = bool(map_entry.get("desbloqueado_por_defecto", false))
	node.shuffle_games = false
	node.reward = raw_node.get("recompensa", {})
	node.fixed_game_entries = _normalize_fixed_game_entries(raw_node.get("juegos", []))
	node.fixed_games = _extract_fixed_game_ids(node.fixed_game_entries)
	node.games = node.fixed_games
	node.game_entries = node.fixed_game_entries
	if not node.fixed_game_entries.is_empty():
		var first_game: Dictionary = node.fixed_game_entries[0]
		node.mode = str(first_game.get("mode", "")).strip_edges()
		node.json_path = str(first_game.get("archivo", "")).strip_edges()
	else:
		var playable_type: String = _normalize_v1_game_type(
			str(raw_node.get("tipo", raw_node.get("mode", ""))).strip_edges()
		)
		node.mode = _map_v1_game_type_to_mode(playable_type)
		node.json_path = node_path.strip_edges()
	if map_entry.has("posicion"):
		node.map_position = _normalize_position(map_entry.get("posicion", {}))
		node.has_map_position = true
	return node


func is_valid() -> bool:
	return not node_key.is_empty() and has_playable_definition()


func has_playable_definition() -> bool:
	return has_content_path() or has_fixed_games() or has_random_game_requests()


func has_content_path() -> bool:
	return not json_path.is_empty() or not activity_id.is_empty()


func has_fixed_games() -> bool:
	return not fixed_game_entries.is_empty()


func has_random_game_requests() -> bool:
	return not random_game_requests.is_empty()


func uses_fixed_games() -> bool:
	return has_fixed_games()


func uses_random_games() -> bool:
	return not has_fixed_games() and has_random_game_requests()


func get_fixed_game_count() -> int:
	return fixed_games.size() if not fixed_games.is_empty() else fixed_game_entries.size()


func get_random_game_request_count() -> int:
	return random_game_requests.size()


# Alias legacy internos.
func has_explicit_games() -> bool:
	return has_fixed_games()


func has_game_slots() -> bool:
	return has_random_game_requests()


func uses_random_slots() -> bool:
	return uses_random_games()


func get_game_count() -> int:
	return get_fixed_game_count()


func get_game_slot_count() -> int:
	return get_random_game_request_count()


func get_effective_pack_id(fallback_pack_id: String = "celiaquia") -> String:
	# pack_id explicito > track del mapa > fallback seguro de demo.
	if not pack_id.is_empty():
		return pack_id
	if not track_key.is_empty():
		return track_key
	return fallback_pack_id.strip_edges()


static func _normalize_fixed_game_entries(raw_games: Variant) -> Array[Dictionary]:
	var normalized_games: Array[Dictionary] = []
	if not raw_games is Array:
		return normalized_games
	for raw_game in raw_games:
		if raw_game is String:
			var act_id: String = str(raw_game).strip_edges()
			if not act_id.is_empty():
				normalized_games.append({
					"id": act_id,
					"tipo": "",
					"mode": "",
					"archivo": "",
					"json_path": "",
					"activity_id": act_id,
					"pack_id": "",
					"difficulty": 0,
					"dificultad": 0,
					"titulo": "",
					"title": "",
				})
			continue
		if not raw_game is Dictionary:
			continue
		var game: Dictionary = raw_game as Dictionary
		var game_type: String = _normalize_v1_game_type(
			str(game.get("tipo", game.get("mode", ""))).strip_edges()
		)
		var game_mode: String = _map_v1_game_type_to_mode(game_type)
		var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
		var activity_id: String = str(game.get("activity_id", "")).strip_edges()
		var pack_id: String = str(game.get("pack_id", "")).strip_edges()
		if activity_id.is_empty() and (
			game_type.is_empty() or game_mode.is_empty() or file_path.is_empty()
		):
			continue
		normalized_games.append(
			{
				"id": str(game.get("id", "")).strip_edges(),
				"tipo": game_type,
				"mode": game_mode,
				"archivo": file_path,
				"json_path": file_path,
				"activity_id": activity_id,
				"pack_id": pack_id,
				"difficulty": int(game.get("difficulty", game.get("dificultad", 0))),
				"dificultad": int(game.get("difficulty", game.get("dificultad", 0))),
				"titulo": str(game.get("titulo", "")).strip_edges(),
				"title": str(game.get("titulo", game.get("title", ""))).strip_edges(),
			}
		)
	return normalized_games


static func _extract_fixed_game_ids(fixed_game_entries: Array[Dictionary]) -> Array[String]:
	var activity_ids: Array[String] = []
	for game_entry in fixed_game_entries:
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			activity_id = str(game_entry.get("id", game_entry.get("json_path", ""))).strip_edges()
		if not activity_id.is_empty():
			activity_ids.append(activity_id)
	return activity_ids


static func extract_fixed_game_ids(fixed_game_entries: Array[Dictionary]) -> Array[String]:
	return _extract_fixed_game_ids(fixed_game_entries)


static func _normalize_random_game_requests(raw_games: Variant) -> Array[Dictionary]:
	var normalized_requests: Array[Dictionary] = []
	if not raw_games is Array:
		return normalized_requests
	for raw_game in raw_games:
		if not raw_game is Dictionary:
			continue
		var game_request: Dictionary = raw_game as Dictionary
		if _has_fixed_game_fields(game_request):
			continue
		var requested_type: String = _normalize_random_game_type(
			str(game_request.get("type", game_request.get("mode", ""))).strip_edges()
		)
		var requested_difficulty: int = int(
			game_request.get("difficulty", game_request.get("dificultad", 0))
		)
		if requested_type.is_empty() or requested_difficulty <= 0:
			continue
		normalized_requests.append(
			{
				"type": requested_type,
				"difficulty": requested_difficulty,
			}
		)
	return normalized_requests


static func _has_fixed_game_fields(game: Dictionary) -> bool:
	var activity_id: String = str(game.get("activity_id", "")).strip_edges()
	var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
	return not activity_id.is_empty() or not file_path.is_empty()


static func _normalize_random_game_type(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"drag", "drag_food":
			return "drag"
		"quiz":
			return "quiz"
		"match", "vinculacion":
			return "match"
		_:
			return ""


static func _normalize_v1_game_type(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"receta_arrastre", "arrastre", MODE_DRAG_DROP:
			return "receta_arrastre"
		"preguntas", MODE_QUIZ_CHOICE:
			return "preguntas"
		"vinculacion", "vinculacion_conceptos":
			return "vinculacion"
		_:
			return ""


static func _map_v1_game_type_to_mode(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"receta_arrastre":
			return MODE_DRAG_DROP
		"preguntas":
			return MODE_QUIZ_CHOICE
		"vinculacion":
			return MODE_VINCULACION_CONCEPTOS
		_:
			return ""


static func _normalize_position(raw_position: Variant) -> Vector2:
	if not raw_position is Dictionary:
		return Vector2.ZERO
	var position: Dictionary = raw_position as Dictionary
	return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))
