extends RefCounted
class_name CargadorDeMapa

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const ContentNormalizerScript := preload("res://sistemas/contenido/ContentNormalizer.gd")
const ContentValidatorScript := preload("res://sistemas/contenido/ContentValidator.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const NODE_JSON_ROOT := "res://contenido/nodos/"
const GAME_JSON_ROOT := "res://contenido/juegos/"
const LOG_PREFIX := "[MAPA]"
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
	print(LOG_PREFIX, " cargar_mapa=", map_json_path)
	var raw_result: Dictionary = read_json_file(map_json_path)
	if not bool(raw_result.get("ok", false)):
		print(LOG_PREFIX, " error=", str(raw_result.get("error", "")))
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
	if node.title.is_empty():
		return "%s no tiene title." % label
	if node.mode.is_empty():
		return "%s no tiene mode." % label
	if not is_supported_map_mode(node.mode):
		return "%s tiene mode no soportado: %s" % [label, node.mode]
	if not node.has_content_path():
		return "%s no tiene json_path ni activity_id." % label
	if node.has_explicit_games():
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
	if not node.node_file_path.is_empty() and not node.has_explicit_games():
		if not FileAccess.file_exists(node.json_path):
			return "No existe el JSON de %s: %s" % [label.to_lower(), node.json_path]
		return ""
	if node.has_explicit_games():
		for game_entry in node.game_entries:
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
	for game_entry in node.game_entries:
		var activity_id: String = str(game_entry.get("activity_id", "")).strip_edges()
		if activity_id.is_empty():
			continue
		var pack_id: String = str(
			game_entry.get("pack_id", node.pack_id if not node.pack_id.is_empty() else node.track_key)
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
		" juegos=", node.game_entries.size(),
		" mode=", node.mode,
		" json_path=", node.json_path
	)
	return _ok(node)


static func is_supported_map_mode(mode: String) -> bool:
	return CONTENT_RULES_BY_MODE.has(mode.strip_edges())


static func _build_v2_mapa(raw_map: Dictionary, source_path: String) -> Dictionary:
	var track_key: String = str(
		raw_map.get("track", raw_map.get("track_key", ""))
	).strip_edges()
	if track_key.is_empty():
		return _error("El mapa v2 necesita campo 'track'.")
	var nodes_dict: Dictionary = raw_map.get("nodes", {}) as Dictionary
	if nodes_dict.is_empty():
		return _error("El mapa v2 no tiene nodos.")
	var sorted_keys: Array = nodes_dict.keys()
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
	print("[MapLoad] path=%s nodes=%d" % [source_path, nodes.size()])
	return _ok({"id": track_key, "track_key": track_key, "title": track_key, "nodes": nodes})


static func _build_v2_node(
	raw_node: Dictionary,
	track_key: String,
	index: int,
	order_key: String
) -> Dictionary:
	var node_key: String = str(raw_node.get("node_key", "")).strip_edges()
	if node_key.is_empty():
		return _error("El nodo '%s' no tiene node_key." % order_key)
	var raw_games: Variant = raw_node.get("games", [])
	if not raw_games is Array or (raw_games as Array).is_empty():
		return _error("El nodo '%s' no tiene games." % node_key)
	if raw_node.has("shuffle_games") and not (raw_node.get("shuffle_games") is bool):
		return _error("Nodo '%s': shuffle_games debe ser bool." % node_key)
	var node: MapNodeData = MapNodeDataScript.from_json(raw_node, track_key, index)
	if node.title.is_empty():
		node.title = "Nodo %d" % (index + 1)
	if node.mode.is_empty() and not node.activity_id.is_empty():
		var act_pack_id: String = (
			node.pack_id if not node.pack_id.is_empty() else track_key
		)
		node.mode = NodeContentLoaderScript.get_activity_mode(act_pack_id, node.activity_id)
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
		"[MapNode] order=%d node_key=%s games=%d"
		% [index + 1, node_key, node.game_entries.size()]
	)
	return _ok(node)


static func _ok(data: Variant) -> Dictionary:
	return {"ok": true, "error": "", "data": data}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
