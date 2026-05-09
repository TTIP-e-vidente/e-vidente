extends RefCounted
class_name CargadorDeMapa

# Lee el JSON del mapa y lo transforma en nodos ordenados.
# Valida estructura basica; no abre juegos ni adapta contenido.

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const ContentNormalizerScript := preload("res://sistemas/contenido/ContentNormalizer.gd")
const ContentValidatorScript := preload("res://sistemas/contenido/ContentValidator.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const NODE_JSON_ROOT := "res://contenido/nodos/"
const LOG_PREFIX := "[MAPA]"
const LOG_PREFIX_MAP_LOAD := "[MapLoad]"
const LOG_PREFIX_MAP_NODE := "[MapNode]"
const DIRECT_PLAYABLE_NODE_TYPES := [
	"receta_arrastre",
	"preguntas",
	"vinculacion",
]
const CONTENT_RULES_BY_MODE := {
	MapNodeData.MODE_QUIZ_CHOICE: {
		"root": NODE_JSON_ROOT,
		"folder": "/preguntas/",
	},
	MapNodeData.MODE_DRAG_DROP: {
		"root": NODE_JSON_ROOT,
		"folder": "/arrastre/",
	},
	MapNodeData.MODE_VINCULACION_CONCEPTOS: {
		"root": NODE_JSON_ROOT,
		"folder": "/vinculacion/",
	},
}

static func load_map(map_json_path: String) -> Dictionary:
	print("%s path=%s" % [LOG_PREFIX_MAP_LOAD, map_json_path])
	var raw_result: Dictionary = read_json_file(map_json_path)
	if not bool(raw_result.get("ok", false)):
		print("%s error=%s" % [LOG_PREFIX_MAP_LOAD, str(raw_result.get("error", ""))])
		return raw_result

	return build_map_data(raw_result.get("data", {}), str(raw_result.get("path", map_json_path)))


static func read_json_file(map_json_path: String) -> Dictionary:
	return ContentJsonLoaderScript.load_json(map_json_path)


static func build_map_data(raw_map: Dictionary, source_path: String = "") -> Dictionary:
	var normalized_result: Dictionary = ContentNormalizerScript.normalize(raw_map, source_path)
	var normalized_map: Dictionary = normalized_result.get("data", {})
	if ContentNormalizerScript.is_v1_content(normalized_map):
		return _build_v1_map(normalized_map, source_path)

	if raw_map.get("nodes") is Dictionary:
		return _build_v2_mapa(raw_map, source_path)

	var header_error: String = validate_map_header(raw_map)
	if not header_error.is_empty():
		return _error(header_error)

	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("track_key", "")).strip_edges()
	var title: String = str(raw_map.get("title", "")).strip_edges()
	var nodes_result: Dictionary = build_nodes(raw_map.get("nodes", []), track_key)
	if not bool(nodes_result.get("ok", false)):
		return nodes_result
	print(
		LOG_PREFIX,
		" legacy id=", map_id,
		" nodos=", (nodes_result.get("data", []) as Array).size()
	)

	return _ok({
		"id": map_id,
		"track_key": track_key,
		"title": title,
		"nodes": nodes_result.get("data", []),
	})


static func _build_v1_map(raw_map: Dictionary, source_path: String) -> Dictionary:
	var validation_result: Dictionary = ContentValidatorScript.validate(raw_map, source_path)
	if not bool(validation_result.get("ok", false)):
		return _error(str(validation_result.get("error", "Mapa invalido.")))

	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("categoria", "")).strip_edges()
	var title: String = str(raw_map.get("titulo", "")).strip_edges()
	var nodes_result: Dictionary = build_nodes(raw_map.get("nodos", []), track_key)
	if not bool(nodes_result.get("ok", false)):
		return nodes_result
	print(LOG_PREFIX, " v1 id=", map_id, " nodos=", (nodes_result.get("data", []) as Array).size())

	return _ok(
		{
			"id": map_id,
			"track_key": track_key,
			"title": title,
			"nodes": nodes_result.get("data", []),
		}
	)


static func validate_map_header(raw_map: Dictionary) -> String:
	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("track_key", "")).strip_edges()
	var title: String = str(raw_map.get("title", "")).strip_edges()
	var raw_nodes: Variant = raw_map.get("nodes", null)
	if map_id.is_empty():
		return "El mapa necesita id."
	if track_key.is_empty():
		return "El mapa necesita track_key."
	if title.is_empty():
		return "El mapa necesita title."
	if not raw_nodes is Array:
		return "El mapa necesita nodes como array."
	return ""


static func build_nodes(raw_nodes: Variant, track_key: String) -> Dictionary:
	if not raw_nodes is Array:
		return _error("El mapa necesita nodes como array.")
	var nodes: Array[MapNodeData] = []
	var seen_node_keys: Dictionary = {}
	for index in range((raw_nodes as Array).size()):
		var node_result: Dictionary = _build_node((raw_nodes as Array)[index], track_key, index)
		if not bool(node_result.get("ok", false)):
			return node_result
		var node_data: MapNodeData = node_result.get("data") as MapNodeData
		var clean_node_key: String = node_data.node_key.strip_edges()
		if seen_node_keys.has(clean_node_key):
			return _error("El mapa repite node_key: %s" % clean_node_key)
		seen_node_keys[clean_node_key] = true
		nodes.append(node_data)
	return _ok(nodes)


static func _build_node(raw_node: Variant, track_key: String, index: int) -> Dictionary:
	var node_number: int = index + 1
	if raw_node is String:
		return _build_node_from_reference(
			{
				"id": str(raw_node).get_file().trim_suffix(".json"),
				"archivo": str(raw_node).strip_edges(),
			},
			track_key,
			index
		)
	if not raw_node is Dictionary:
		return _error("El nodo %d del mapa debe ser un objeto." % node_number)
	if _is_content_node_reference(raw_node as Dictionary):
		return _build_node_from_reference(raw_node as Dictionary, track_key, index)

	var node := MapNodeDataScript.from_json(raw_node as Dictionary, track_key, index)
	var node_error: String = validate_map_node(node, node_number)
	if not node_error.is_empty():
		return _error(node_error)

	return _ok(node)


static func validate_map_node(node: MapNodeData, node_number: int = 0) -> String:
	var label: String = "El nodo"
	if node_number > 0:
		label = "El nodo %d" % node_number
	if node.node_key.is_empty():
		return "%s no tiene node_key." % label
	# Los games random no necesitan title/mode/json_path en el nodo.
	if node.has_random_game_requests():
		return ""
	if node.title.is_empty():
		return "%s no tiene title." % label
	if node.mode.is_empty():
		return "%s no tiene mode." % label
	if not is_supported_map_mode(node.mode):
		return "%s tiene mode no soportado: %s" % [label, node.mode]
	if not node.has_content_path():
		return "%s no tiene json_path ni activity_id." % label
	if node.has_fixed_games():
		var games_error: String = _validate_activity_games(node, label)
		if not games_error.is_empty():
			if node.json_path.is_empty():
				return games_error
			push_warning("%s. Se usara json_path como fallback." % games_error)
	if not node.activity_id.is_empty():
		var pack_id: String = node.pack_id if not node.pack_id.is_empty() else node.track_key
		var activity_result: Dictionary = NodeContentLoaderScript.has_activity(
			pack_id,
			node.activity_id
		)
		if not bool(activity_result.get("ok", false)):
			var activity_error: String = "%s tiene activity_id invalido: %s" % [
				label,
				str(activity_result.get("error", "")),
			]
			if node.json_path.is_empty():
				return activity_error
			push_warning("%s. Se usara json_path como fallback." % activity_error)
		else:
			return ""
	if not node.node_file_path.is_empty() and not node.has_fixed_games():
		if not FileAccess.file_exists(node.json_path):
			return "No existe el JSON de %s: %s" % [label.to_lower(), node.json_path]
		return ""
	if node.has_fixed_games():
		for game_entry in node.fixed_game_entries:
			var file_path: String = str(game_entry.get("archivo", "")).strip_edges()
			if file_path.is_empty() or not FileAccess.file_exists(file_path):
				return "No existe el JSON de %s: %s" % [label.to_lower(), file_path]
		return ""
	var content_rule: Dictionary = CONTENT_RULES_BY_MODE.get(node.mode, {})
	var expected_root: String = str(content_rule.get("root", NODE_JSON_ROOT)).strip_edges()
	if not node.json_path.begins_with(expected_root):
		return "%s debe apuntar a %s. Ruta actual: %s" % [label, expected_root, node.json_path]
	var expected_folder: String = str(content_rule.get("folder", "")).strip_edges()
	if not expected_folder.is_empty() and not node.json_path.contains(expected_folder):
		return "%s debe apuntar a %s para mode=%s. Ruta actual: %s" % [
			label,
			expected_folder,
			node.mode,
			node.json_path,
		]
	if not FileAccess.file_exists(node.json_path):
		return "No existe el JSON de %s: %s" % [label.to_lower(), node.json_path]
	return ""


static func _validate_activity_games(node: MapNodeData, label: String) -> String:
	for game_entry in node.fixed_game_entries:
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			continue
		var pack_id: String = str(
			game_entry.get(
				"pack_id",
				node.pack_id if not node.pack_id.is_empty() else node.track_key
			)
		).strip_edges()
		var activity_result: Dictionary = NodeContentLoaderScript.has_activity(pack_id, activity_id)
		if not bool(activity_result.get("ok", false)):
			return "%s tiene game activity_id invalido: %s" % [
				label,
				str(activity_result.get("error", "")),
			]
	return ""


static func _is_content_node_reference(raw_node: Dictionary) -> bool:
	return not str(raw_node.get("archivo", "")).strip_edges().is_empty()


static func _build_node_from_reference(
	raw_node: Dictionary,
	track_key: String,
	index: int
) -> Dictionary:
	var node_number: int = index + 1
	var node_path: String = str(raw_node.get("archivo", "")).strip_edges()
	var raw_result: Dictionary = ContentJsonLoaderScript.load_json(node_path)
	if not bool(raw_result.get("ok", false)):
		return _error(str(raw_result.get("error", "No se pudo cargar el nodo.")))

	var clean_path: String = str(raw_result.get("path", node_path)).strip_edges()
	var normalized_result: Dictionary = ContentNormalizerScript.normalize(
		raw_result.get("data", {}),
		clean_path
	)
	var normalized_node: Dictionary = normalized_result.get("data", {})
	if not ContentNormalizerScript.is_v1_content(normalized_node):
		return _error("El nodo %d debe usar un archivo V1." % node_number)
	var node_type: String = str(normalized_node.get("tipo", "")).strip_edges()
	if node_type != "nodo" and not DIRECT_PLAYABLE_NODE_TYPES.has(node_type):
		return _error("El archivo referenciado no es un nodo jugable valido: %s" % clean_path)

	var validation_result: Dictionary = ContentValidatorScript.validate(
		normalized_node,
		clean_path
	)
	if not bool(validation_result.get("ok", false)):
		return _error(str(validation_result.get("error", "Nodo invalido.")))

	var node := MapNodeDataScript.from_v1_node(
		normalized_node,
		track_key,
		index,
		raw_node,
		clean_path
	)
	var node_error: String = validate_map_node(node, node_number)
	if not node_error.is_empty():
		return _error(node_error)
	print(
		LOG_PREFIX,
		" nodo_v1=", node.node_key,
		" juegos=", node.fixed_game_entries.size(),
		" mode=", node.mode,
		" json_path=", node.json_path
	)
	return _ok(node)


static func is_supported_map_mode(mode: String) -> bool:
	return CONTENT_RULES_BY_MODE.has(mode.strip_edges())


static func _build_v2_mapa(raw_map: Dictionary, source_path: String) -> Dictionary:
	# Mapa v2: usa nodes como Dictionary ordenado por claves "1", "2", "3".
	var track_key: String = str(
		raw_map.get("track", raw_map.get("track_key", ""))
	).strip_edges()
	if track_key.is_empty():
		return _error("El mapa v2 necesita campo 'track'.")
	if int(raw_map.get("version", 0)) <= 0:
		return _error("El mapa v2 necesita campo 'version'.")
	var nodes_dict: Dictionary = raw_map.get("nodes", {}) as Dictionary
	if nodes_dict.is_empty():
		return _error("El mapa v2 no tiene nodos.")
	var sorted_keys: Array[String] = []
	for raw_key in nodes_dict.keys():
		var order_key: String = str(raw_key).strip_edges()
		if not order_key.is_valid_int() or int(order_key) <= 0:
			return _error("El mapa v2 usa una clave de nodo invalida: %s" % order_key)
		sorted_keys.append(order_key)
	sorted_keys.sort_custom(func(a, b): return int(a) < int(b))
	var nodes: Array[MapNodeData] = []
	var seen_node_keys: Dictionary = {}
	for i in range(sorted_keys.size()):
		var order_key: String = str(sorted_keys[i])
		var raw_node_val: Variant = nodes_dict.get(order_key, {})
		if not raw_node_val is Dictionary:
			return _error("El nodo '%s' debe ser un objeto." % order_key)
		var node_result: Dictionary = _build_v2_node(
			raw_node_val as Dictionary, track_key, i, order_key
		)
		if not bool(node_result.get("ok", false)):
			return node_result
		var node_data: MapNodeData = node_result.get("data") as MapNodeData
		var clean_node_key: String = node_data.node_key.strip_edges()
		if seen_node_keys.has(clean_node_key):
			return _error("El mapa repite node_key: %s" % clean_node_key)
		seen_node_keys[clean_node_key] = true
		nodes.append(node_data)
	if not source_path.is_empty():
		print("%s path=%s" % [LOG_PREFIX_MAP_LOAD, source_path])
	print("%s nodes=%d" % [LOG_PREFIX_MAP_LOAD, nodes.size()])
	return _ok({"id": track_key, "track_key": track_key, "title": track_key, "nodes": nodes})


static func _build_v2_node(
	raw_node: Dictionary,
	track_key: String,
	index: int,
	order_key: String
) -> Dictionary:
	# Cada nodo v2 usa node_key + games + shuffle_games.
	# Valida que games sea homogeneo:
	# - todos String => fixed
	# - todos Dictionary => random
	# - mezcla => error controlado
	var node_key: String = str(raw_node.get("node_key", "")).strip_edges()
	if node_key.is_empty():
		return _error("El nodo '%s' no tiene node_key." % order_key)
	var raw_games: Variant = raw_node.get("games", [])
	var raw_legacy_game_slots: Variant = raw_node.get("game_slots", [])
	var has_games: bool = raw_games is Array and not (raw_games as Array).is_empty()
	var has_legacy_random_games: bool = (
		raw_legacy_game_slots is Array and not (raw_legacy_game_slots as Array).is_empty()
	)
	var games_style: String = ""
	if has_games:
		games_style = _detect_v2_games_style(raw_games as Array)
	if raw_node.has("game_slots") and not raw_legacy_game_slots is Array:
		return _error("Nodo '%s': game_slots debe ser array." % node_key)
	if raw_node.has("games") and not raw_games is Array:
		return _error("Nodo '%s': games debe ser array." % node_key)
	if not has_games and not has_legacy_random_games:
		return _error("El nodo '%s' necesita games." % node_key)
	if has_games and games_style == "invalid":
		return _error("Nodo '%s': games tiene formato invalido." % node_key)
	if has_games and games_style == "mixed":
		push_warning("[MapNode] node=%s games mezcla strings y requests random." % node_key)
		return _error(
			"Nodo '%s': games mezcla strings y requests random. Usar un solo tipo." % node_key
		)
	if has_games and games_style == "fixed":
		var games_error: String = _validate_v2_fixed_games(raw_games as Array, node_key)
		if not games_error.is_empty():
			return _error(games_error)
	if has_games and games_style == "random":
		var requests_error: String = _validate_v2_random_game_requests(
			raw_games as Array,
			node_key,
			"games"
		)
		if not requests_error.is_empty():
			return _error(requests_error)
	if not has_games and has_legacy_random_games:
		push_warning(
			"[MapNode] game_slots legacy detectado. Usar games con objetos random. node=%s"
			% node_key
		)
		var legacy_requests_error: String = _validate_v2_random_game_requests(
			raw_legacy_game_slots as Array,
			node_key,
			"game_slots"
		)
		if not legacy_requests_error.is_empty():
			return _error(legacy_requests_error)
	if has_games and has_legacy_random_games:
		push_warning("Nodo '%s' define games y game_slots. Se prefiere games." % node_key)
	if raw_node.has("shuffle_games") and not (raw_node.get("shuffle_games") is bool):
		return _error("Nodo '%s': shuffle_games debe ser bool." % node_key)
	var node: MapNodeData = MapNodeDataScript.from_json(raw_node, track_key, index)
	if node.title.is_empty():
		node.title = "Nodo %d" % (index + 1)
	if node.uses_fixed_games():
		var node_error: String = _hydrate_v2_fixed_games(node, track_key)
		if not node_error.is_empty():
			return _error(node_error)
		if not node.has_content_path():
			return _error("Nodo '%s': games no contiene activity_id valido." % node_key)
		if node.mode.is_empty():
			return _error(
				"Nodo '%s': no se pudo determinar mode (activity_id='%s')." % [
					node_key, node.activity_id
				]
			)
		if not is_supported_map_mode(node.mode):
			return _error("Nodo '%s' tiene mode no soportado: %s." % [node_key, node.mode])
		print(
			"%s order=%d mode=fixed games=%d shuffle=%s"
			% [
				LOG_PREFIX_MAP_NODE,
				node.order,
				node.get_fixed_game_count(),
				str(node.shuffle_games),
			]
		)
		return _ok(node)
	print(
		"%s order=%d mode=random requests=%d shuffle=%s"
		% [
			LOG_PREFIX_MAP_NODE,
			node.order,
			node.get_random_game_request_count(),
			str(node.shuffle_games),
		]
	)
	return _ok(node)


static func _validate_v2_fixed_games(raw_games: Array, node_key: String) -> String:
	for game_index in range(raw_games.size()):
		var raw_game: Variant = raw_games[game_index]
		if raw_game is String:
			if str(raw_game).strip_edges().is_empty():
				return "Nodo '%s': games[%d] no puede ser string vacio." % [node_key, game_index]
			continue
		if not raw_game is Dictionary:
			return "Nodo '%s': games[%d] debe ser string u objeto." % [node_key, game_index]
		var game: Dictionary = raw_game as Dictionary
		var activity_id: String = str(game.get("activity_id", "")).strip_edges()
		var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
		if activity_id.is_empty() and file_path.is_empty():
			return "Nodo '%s': games[%d] necesita activity_id o json_path." % [node_key, game_index]
	return ""


static func _validate_v2_random_game_requests(
	raw_games: Array,
	node_key: String,
	field_name: String
) -> String:
	for game_index in range(raw_games.size()):
		var raw_slot: Variant = raw_games[game_index]
		if not raw_slot is Dictionary:
			return "Nodo '%s': %s[%d] debe ser objeto." % [node_key, field_name, game_index]
		var slot: Dictionary = raw_slot as Dictionary
		if _looks_like_v2_explicit_game(slot):
			return "Nodo '%s': %s[%d] no puede mezclar game explicito con request random." % [
				node_key,
				field_name,
				game_index,
			]
		var slot_type: String = _normalize_v2_random_game_type(
			str(slot.get("type", slot.get("mode", ""))).strip_edges()
		)
		if slot_type.is_empty():
			return "Nodo '%s': %s[%d] tiene type invalido." % [node_key, field_name, game_index]
		var difficulty: int = int(slot.get("difficulty", slot.get("dificultad", 0)))
		if difficulty < 1 or difficulty > 3:
			return "Nodo '%s': %s[%d] tiene difficulty invalida." % [
				node_key,
				field_name,
				game_index,
			]
	return ""


static func _detect_v2_games_style(raw_games: Array) -> String:
	var has_fixed_games := false
	var has_random_games := false
	for raw_game in raw_games:
		if raw_game is String:
			has_fixed_games = true
			continue
		if not raw_game is Dictionary:
			return "invalid"
		var game: Dictionary = raw_game as Dictionary
		if _looks_like_v2_random_game_request(game):
			has_random_games = true
			continue
		if _looks_like_v2_explicit_game(game):
			has_fixed_games = true
			continue
		return "invalid"
	if has_fixed_games and has_random_games:
		return "mixed"
	if has_fixed_games:
		return "fixed"
	if has_random_games:
		return "random"
	return "invalid"


static func _looks_like_v2_random_game_request(game: Dictionary) -> bool:
	if _looks_like_v2_explicit_game(game):
		return false
	return not _normalize_v2_random_game_type(
		str(game.get("type", game.get("mode", ""))).strip_edges()
	).is_empty()


static func _looks_like_v2_explicit_game(game: Dictionary) -> bool:
	var activity_id: String = str(game.get("activity_id", "")).strip_edges()
	var file_path: String = str(game.get("archivo", game.get("json_path", ""))).strip_edges()
	return not activity_id.is_empty() or not file_path.is_empty()


static func _normalize_v2_random_game_type(raw_type: String) -> String:
	match raw_type.strip_edges().to_lower():
		"drag", "drag_food":
			return "drag"
		"quiz":
			return "quiz"
		"match", "vinculacion":
			return "match"
		_:
			return ""


static func _hydrate_v2_fixed_games(node: MapNodeData, track_key: String) -> String:
	# Resuelve pack_id y mode de los games fijos sin abrir escenas ni alterar el JSON original.
	if node == null or node.fixed_game_entries.is_empty():
		return "Nodo sin games validos."

	for game_index in range(node.fixed_game_entries.size()):
		var game_entry: Dictionary = (
			node.fixed_game_entries[game_index] as Dictionary
		).duplicate(true)
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			return "Nodo '%s': games no contiene activity_id valido." % node.node_key
		var pack_id: String = str(game_entry.get("pack_id", "")).strip_edges()
		if pack_id.is_empty():
			pack_id = node.get_effective_pack_id(track_key)
		var activity_result: Dictionary = NodeContentLoaderScript.load_activity(
			pack_id,
			activity_id
		)
		if not bool(activity_result.get("ok", false)):
			return "Nodo '%s': game '%s' invalido: %s" % [
				node.node_key,
				activity_id,
				str(activity_result.get("error", "")),
			]
		var activity_data: Dictionary = activity_result.get("data", {})
		var mode: String = NodeContentLoaderScript.to_runtime_mode(
			str(activity_data.get("mode", "")).strip_edges()
		)
		if not is_supported_map_mode(mode):
			return "Nodo '%s': game '%s' tiene mode no soportado." % [
				node.node_key,
				activity_id,
			]
		game_entry["activity_id"] = activity_id
		game_entry["pack_id"] = pack_id
		game_entry["mode"] = mode
		game_entry["tipo"] = mode
		node.fixed_game_entries[game_index] = game_entry

	node.game_entries = node.fixed_game_entries
	var first_game: Dictionary = node.fixed_game_entries[0]
	node.activity_id = str(first_game.get("activity_id", "")).strip_edges()
	node.pack_id = str(
		first_game.get("pack_id", node.get_effective_pack_id(track_key))
	).strip_edges()
	node.mode = str(first_game.get("mode", "")).strip_edges()
	node.fixed_games = MapNodeDataScript.extract_fixed_game_ids(node.fixed_game_entries)
	node.games = node.fixed_games
	return ""


static func _ok(data: Variant) -> Dictionary:
	return {"ok": true, "error": "", "data": data}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
