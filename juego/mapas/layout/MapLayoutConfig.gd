class_name MapLayoutConfig
extends RefCounted

var route_id: String = ""
var placement_mode: String = "curve"
var start_margin: float = 40.0
var end_margin: float = 40.0

const _VALID_PLACEMENT_MODES: PackedStringArray = ["curve", "anchors"]


static func desde_json(raw: Dictionary) -> MapLayoutConfig:
	var config := MapLayoutConfig.new()
	config.route_id = str(raw.get("route_id", "")).strip_edges()
	var raw_mode: String = str(raw.get("placement_mode", "curve")).strip_edges()
	if raw_mode in _VALID_PLACEMENT_MODES:
		config.placement_mode = raw_mode
	else:
		push_warning(
			"MapLayoutConfig: placement_mode desconocido '%s', usando 'curve'" % raw_mode
		)
		config.placement_mode = "curve"
	config.start_margin = float(raw.get("start_margin", 40.0))
	config.end_margin = float(raw.get("end_margin", 40.0))
	return config


func es_modo_anchors() -> bool:
	return placement_mode == "anchors"


func es_valido() -> bool:
	return not route_id.is_empty()
