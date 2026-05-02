extends RefCounted
class_name MapJsonLoader

const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const NODE_JSON_ROOT := "res://contenido/nodos/"


static func load_map(map_json_path: String) -> Dictionary:
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

	return _validate_map(raw_data as Dictionary)


static func _validate_map(raw_map: Dictionary) -> Dictionary:
	var map_id: String = str(raw_map.get("id", "")).strip_edges()
	var track_key: String = str(raw_map.get("track_key", "")).strip_edges()
	var title: String = str(raw_map.get("title", "")).strip_edges()
	var raw_nodes: Variant = raw_map.get("nodes", null)

	if map_id.is_empty():
		return _error("El mapa necesita id.")
	if track_key.is_empty():
		return _error("El mapa necesita track_key.")
	if title.is_empty():
		return _error("El mapa necesita title.")
	if not raw_nodes is Array:
		return _error("El mapa necesita nodes como array.")

	var nodes: Array[MapNodeData] = []
	for index in range((raw_nodes as Array).size()):
		var node_result: Dictionary = _validate_node((raw_nodes as Array)[index], track_key, index)
		if not bool(node_result.get("ok", false)):
			return node_result
		nodes.append(node_result.get("data") as MapNodeData)

	return {
		"ok": true,
		"error": "",
		"data": {
			"id": map_id,
			"track_key": track_key,
			"title": title,
			"nodes": nodes,
		}
	}


static func _validate_node(raw_node: Variant, track_key: String, index: int) -> Dictionary:
	var node_number: int = index + 1
	if not raw_node is Dictionary:
		return _error("El nodo %d del mapa debe ser un objeto." % node_number)

	var node := MapNodeDataScript.from_json(raw_node as Dictionary, track_key, index)
	if node.node_key.is_empty():
		return _error("El nodo %d no tiene node_key." % node_number)
	if node.title.is_empty():
		return _error("El nodo %d no tiene title." % node_number)
	if node.json_path.is_empty():
		return _error("El nodo %d no tiene json_path." % node_number)
	if not node.json_path.begins_with(NODE_JSON_ROOT):
		return _error(
			"El nodo %d debe apuntar a %s. Ruta actual: %s"
			% [node_number, NODE_JSON_ROOT, node.json_path]
		)
	if not FileAccess.file_exists(node.json_path):
		return _error("No existe el JSON del nodo %d: %s" % [node_number, node.json_path])

	return {"ok": true, "error": "", "data": node}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
