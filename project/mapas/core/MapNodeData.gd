extends RefCounted
class_name MapNodeData

# Representa los datos de un nodo del mapa.
#
# Responsabilidad única: guardar qué nodo es y qué games tiene.
# No carga JSON, no busca activities y no abre escenas.
#
# Todos los games del nodo van en el array "games".
# Cómo distinguir si una entrada es fija o random:
#   - fija:  tiene "activity_id" no vacío (sabe exactamente qué activity cargar).
#   - random: tiene "type" y "difficulty" pero "activity_id" vacío (pide un game por criterio).
#
# Lectura simple:
#   node.has_fixed_games()          → hay al menos un game con activity_id explícito.
#   node.has_random_game_requests() → hay al menos un request de game random.
#   node.uses_random_games()        → es un nodo con games aleatorios (sin fijos).
#   node.get_fixed_games()          → devuelve sólo las entradas fijas.
#   node.get_random_game_requests() → devuelve sólo los requests random.

const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_DRAG_DROP := "drag_drop"
const MODE_VINCULACION_CONCEPTOS := "vinculacion_conceptos"

# Identidad del nodo.
var node_key: String = ""       # ID único del nodo en el mapa.
var order: int = 0              # Posición 1-based (usada en logs).
var index: int = 0              # Posición 0-based (usada en código).
var title: String = ""          # Título visible del nodo.
var track_key: String = ""      # Pista a la que pertenece (ej: "celiaquia").

# Configuración de games.
var shuffle_games := false      # Si true, ArmadorDePartida mezcla el orden de los games.
var default_unlocked := false   # Si true, el nodo empieza desbloqueado.

# Todos los games del nodo, fijos y random juntos.
# Entradas fijas:  activity_id no vacío.
# Requests random: type no vacío, activity_id vacío.
var games: Array[Dictionary] = []

# Campos de la ruta legacy (nodos V1 con json_path directo).
# En nodos nuevos, estos quedan vacíos y se usan fixed_game_entries.
var mode: String = ""           # Mode del primer game (legacy/V1).
var json_path: String = ""      # Ruta al JSON legacy (si no hay activity_id).
var activity_id: String = ""    # activity_id del primer game (camino feliz).
var pack_id: String = ""        # Pack al que pertenece el activity_id.
var difficulty: int = 0         # Dificultad base del nodo (0 = auto).
var node_file_path: String = "" # Ruta del archivo del nodo V1 (legacy).

# Posición visual en el mapa (solo nodos V1 con coordenadas explícitas).
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
	var fixed_games := _normalize_fixed_game_entries(raw_games)
	var random_requests := _normalize_random_game_requests(raw_games)
	if random_requests.is_empty():
		random_requests = _normalize_random_game_requests(raw_legacy_game_slots)
	if fixed_games.is_empty() and not node.activity_id.is_empty():
		fixed_games.push_back({
			"activity_id": node.activity_id,
			"pack_id": node.pack_id,
			"difficulty": node.difficulty,
			"dificultad": node.difficulty,
		})
	node.games = fixed_games + random_requests
	if not fixed_games.is_empty():
		var first_game: Dictionary = fixed_games[0]
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
	node.node_file_path = node_path.strip_edges()
	node.default_unlocked = bool(map_entry.get("desbloqueado_por_defecto", false))
	node.shuffle_games = false
	node.games = _normalize_fixed_game_entries(raw_node.get("juegos", []))
	if not node.games.is_empty():
		var first_game: Dictionary = node.games[0]
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
	for g in games:
		if not is_random_game_request(g):
			return true
	return false


func has_random_game_requests() -> bool:
	for g in games:
		if is_random_game_request(g):
			return true
	return false


func uses_fixed_games() -> bool:
	return has_fixed_games()


func uses_random_games() -> bool:
	return not has_fixed_games() and has_random_game_requests()


func get_fixed_game_count() -> int:
	var count := 0
	for g in games:
		if not is_random_game_request(g):
			count += 1
	return count


func get_random_game_request_count() -> int:
	var count := 0
	for g in games:
		if is_random_game_request(g):
			count += 1
	return count


# Devuelve solo las entradas fijas del array games (las que tienen activity_id).
func get_fixed_games() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in games:
		if not is_random_game_request(g):
			result.append(g)
	return result


# Devuelve solo los requests random del array games (los que tienen type pero no activity_id).
func get_random_game_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in games:
		if is_random_game_request(g):
			result.append(g)
	return result


# Devuelve true si la entrada es un request random (tiene type, no tiene activity_id).
static func is_random_game_request(game: Dictionary) -> bool:
	var has_type := not str(game.get("type", "")).strip_edges().is_empty()
	var has_activity_id := not str(game.get("activity_id", "")).strip_edges().is_empty()
	return has_type and not has_activity_id


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
		var entry_activity_id: String = str(game.get("activity_id", "")).strip_edges()
		var entry_pack_id: String = str(game.get("pack_id", "")).strip_edges()
		if entry_activity_id.is_empty() and (
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
				"activity_id": entry_activity_id,
				"pack_id": entry_pack_id,
				"difficulty": int(game.get("difficulty", game.get("dificultad", 0))),
				"dificultad": int(game.get("difficulty", game.get("dificultad", 0))),
				"titulo": str(game.get("titulo", "")).strip_edges(),
				"title": str(game.get("titulo", game.get("title", ""))).strip_edges(),
			}
		)
	return normalized_games


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
	var entry_activity_id: String = str(game.get("activity_id", "")).strip_edges()
	var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
	return not entry_activity_id.is_empty() or not file_path.is_empty()


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
