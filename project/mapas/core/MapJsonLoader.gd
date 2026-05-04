extends RefCounted
class_name MapJsonLoader

const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const NODE_JSON_ROOT := "res://contenido/nodos/"
const CONTENT_RULES_BY_MODE := {
	MapNodeData.MODE_QUIZ_CHOICE: {
		"root": NODE_JSON_ROOT,
		"folder": "/preguntas/",
	},
	MapNodeData.MODE_DRAG_DROP: {
		"root": NODE_JSON_ROOT,
		"folder": "/arrastre/",
	},
}

static func load_map(map_json_path: String) -> Dictionary:
	var raw_result: Dictionary = read_json_file(map_json_path)
	if not bool(raw_result.get("ok", false)):
		return raw_result

	return build_map_data(raw_result.get("data", {}))


static func read_json_file(map_json_path: String) -> Dictionary:
	var clean_path: String = map_json_path.strip_edges()
	if clean_path.is_empty():
		return _error("Falta la ruta del JSON del mapa.")
	if not FileAccess.file_exists(clean_path):
		return _error("No existe el JSON del mapa: %s" % clean_path)

	var file := FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		return _error("No se pudo abrir el JSON del mapa: %s" % clean_path)

	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	if parse_result != OK:
		return _error(
			"JSON invalido en %s linea %d: %s"
			% [clean_path, parser.get_error_line(), parser.get_error_message()]
		)

	var raw_data: Variant = parser.get_data()
	if not raw_data is Dictionary:
		return _error("El JSON del mapa debe ser un objeto.")

	return _ok(raw_data as Dictionary)


static func build_map_data(raw_map: Dictionary) -> Dictionary:
	var header_error: String = validate_map_header(raw_map)
	if not header_error.is_empty():
		return _error(header_error)

	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("track_key", "")).strip_edges()
	var title: String = str(raw_map.get("title", "")).strip_edges()
	var nodes_result: Dictionary = build_nodes(raw_map.get("nodes", []), track_key)
	if not bool(nodes_result.get("ok", false)):
		return nodes_result

	return _ok({
		"id": map_id,
		"track_key": track_key,
		"title": title,
		"nodes": nodes_result.get("data", []),
	})


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
	if not raw_node is Dictionary:
		return _error("El nodo %d del mapa debe ser un objeto." % node_number)

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
		return "%s no tiene json_path." % label
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


static func is_supported_map_mode(mode: String) -> bool:
	return CONTENT_RULES_BY_MODE.has(mode.strip_edges())


static func _ok(data: Variant) -> Dictionary:
	return {"ok": true, "error": "", "data": data}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
