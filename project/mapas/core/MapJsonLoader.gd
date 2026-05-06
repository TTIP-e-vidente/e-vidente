extends "res://mapas/logica/CargadorDeMapa.gd"
class_name MapJsonLoader

const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")

static func load_map(map_json_path: String) -> Dictionary:
	return CargadorDeMapaScript.load_map(map_json_path)


static func read_json_file(map_json_path: String) -> Dictionary:
	return CargadorDeMapaScript.read_json_file(map_json_path)


static func build_map_data(raw_map: Dictionary) -> Dictionary:
	return CargadorDeMapaScript.build_map_data(raw_map)


static func validate_map_header(raw_map: Dictionary) -> String:
	return CargadorDeMapaScript.validate_map_header(raw_map)


static func build_nodes(raw_nodes: Variant, track_key: String) -> Dictionary:
	return CargadorDeMapaScript.build_nodes(raw_nodes, track_key)


static func validate_map_node(node: MapNodeData, node_number: int = 0) -> String:
	return CargadorDeMapaScript.validate_map_node(node, node_number)


static func is_supported_map_mode(mode: String) -> bool:
	return CargadorDeMapaScript.is_supported_map_mode(mode)
