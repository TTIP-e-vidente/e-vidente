extends RefCounted
class_name MapLayoutConfig

const SPACING_EVEN := "even"
const SPACING_SPACE_BETWEEN := "space_between"
const SPACING_SPACE_AROUND := "space_around"

const SPACING_MODES_VALIDOS := [SPACING_EVEN, SPACING_SPACE_BETWEEN, SPACING_SPACE_AROUND]

var route_id: String = "RutaCeliaquia1"
var spacing_mode: String = SPACING_EVEN
var spacing_factor: float = 1.0
var start_margin: float = 0.0
var end_margin: float = 0.0


static func desde_json(raw_layout: Variant) -> MapLayoutConfig:
	var config := MapLayoutConfig.new()
	if not raw_layout is Dictionary:
		return config
	var d: Dictionary = raw_layout as Dictionary
	var raw_route_id: String = str(d.get("route_id", "")).strip_edges()
	if not raw_route_id.is_empty():
		config.route_id = raw_route_id
	var raw_mode: String = str(d.get("spacing_mode", "")).strip_edges()
	if SPACING_MODES_VALIDOS.has(raw_mode):
		config.spacing_mode = raw_mode
	elif not raw_mode.is_empty():
		push_warning("[MapLayoutConfig] spacing_mode desconocido: '%s'. Usando 'even'." % raw_mode)
	var raw_factor: Variant = d.get("spacing_factor", null)
	if raw_factor != null:
		config.spacing_factor = maxf(0.1, float(raw_factor))
	var raw_start: Variant = d.get("start_margin", null)
	if raw_start != null:
		config.start_margin = maxf(0.0, float(raw_start))
	var raw_end: Variant = d.get("end_margin", null)
	if raw_end != null:
		config.end_margin = maxf(0.0, float(raw_end))
	return config


func obtener_route_id() -> String:
	return route_id


func obtener_modo_espaciado() -> String:
	return spacing_mode


func obtener_factor_espaciado() -> float:
	return spacing_factor


func obtener_margen_inicio() -> float:
	return start_margin


func obtener_margen_final() -> float:
	return end_margin
