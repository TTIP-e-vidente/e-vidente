extends RefCounted
class_name MapNodeData

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
var games: Array[String] = []
var difficulty: int = 0
var description: String = ""
var node_file_path: String = ""
var game_entries: Array[Dictionary] = []
var shuffle_games := false
var default_unlocked := false
var reward: Dictionary = {}
var map_position := Vector2.ZERO
var has_map_position := false


# V2 simple: guarda order + games como lista de activity_id.
# game_entries conserva los metadatos que todavia necesita el flujo legacy.
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
	node.game_entries = _normalize_explicit_games(raw_node.get("games", []))
	if node.game_entries.is_empty() and not node.activity_id.is_empty():
		node.game_entries.append({
			"activity_id": node.activity_id,
			"pack_id": node.pack_id,
			"difficulty": node.difficulty,
			"dificultad": node.difficulty,
		})
	node.games = _extract_game_ids(node.game_entries)
	if not node.game_entries.is_empty():
		var first_game: Dictionary = node.game_entries[0]
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
	node.game_entries = _normalize_explicit_games(raw_node.get("juegos", []))
	node.games = _extract_game_ids(node.game_entries)
	if not node.game_entries.is_empty():
		var first_game: Dictionary = node.game_entries[0]
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
	return not node_key.is_empty() and has_content_path()


func has_content_path() -> bool:
	return not json_path.is_empty() or not activity_id.is_empty()


func has_explicit_games() -> bool:
	return not game_entries.is_empty()


func get_game_count() -> int:
	return games.size() if not games.is_empty() else game_entries.size()


func get_effective_pack_id(fallback_pack_id: String = "celiaquia") -> String:
	if not pack_id.is_empty():
		return pack_id
	if not track_key.is_empty():
		return track_key
	return fallback_pack_id.strip_edges()


static func _normalize_explicit_games(raw_games: Variant) -> Array[Dictionary]:
	var games: Array[Dictionary] = []
	if not raw_games is Array:
		return games
	for raw_game in raw_games:
		if raw_game is String:
			var act_id: String = str(raw_game).strip_edges()
			if not act_id.is_empty():
				games.append({
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
		games.append(
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
	return games


static func _extract_game_ids(game_entries: Array[Dictionary]) -> Array[String]:
	var activity_ids: Array[String] = []
	for game_entry in game_entries:
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			activity_id = str(game_entry.get("id", game_entry.get("json_path", ""))).strip_edges()
		if not activity_id.is_empty():
			activity_ids.append(activity_id)
	return activity_ids


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
