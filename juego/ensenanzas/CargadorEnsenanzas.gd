extends RefCounted
class_name CargadorEnsenanzas

const RUTA_JSON := "res://contenido/mapa/ensenanzas.json"
const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const LEGACY_TEACHING_KEY_ALIASES := {
	"celiaquia_cocina_segura": "ensenanza_contaminacion",
	"celiaquia_compras": "ensenanza_etiquetas",
	"celiaquia_salud": "ensenanza_sintomas",
}

static var _cache_por_clave: Dictionary = {}
static var _cache_por_id: Dictionary = {}
static var _cargado: bool = false


static func _asegurar_carga() -> void:
	if _cargado:
		return
	_cargado = true
	_cache_por_clave.clear()
	_cache_por_id.clear()

	var resultado: Dictionary = ContentJsonLoaderScript.cargar_json(RUTA_JSON)
	if not bool(resultado.get("ok", false)):
		push_warning("CargadorEnsenanzas: %s" % str(resultado.get("error", "")))
		return

	var datos: Variant = resultado.get("data", {})
	if not datos is Dictionary:
		push_warning("CargadorEnsenanzas: el JSON raiz debe ser un objeto.")
		return

	for clave_raw in (datos as Dictionary).keys():
		var entrada: Variant = (datos as Dictionary)[clave_raw]
		if not entrada is Dictionary:
			continue
		var ensenanza: Ensenanza = _construir_ensenanza(str(clave_raw), entrada as Dictionary)
		if ensenanza == null:
			continue
		_cache_por_clave[ensenanza.clave] = ensenanza
		if not ensenanza.id.is_empty():
			_cache_por_id[ensenanza.id.to_lower()] = ensenanza


static func _construir_ensenanza(clave: String, datos: Dictionary) -> Ensenanza:
	var ensenanza := Ensenanza.new()
	ensenanza.clave = clave.strip_edges().to_lower()
	ensenanza.id = str(datos.get("id", "")).strip_edges()
	ensenanza.titulo = str(datos.get("titulo", "")).strip_edges()
	ensenanza.texto = str(datos.get("texto", "")).strip_edges()
	ensenanza.imagen = str(datos.get("imagen", "")).strip_edges()
	if ensenanza.titulo.is_empty() and ensenanza.texto.is_empty() and ensenanza.imagen.is_empty():
		return null
	return ensenanza


static func _buscar_por_clave_json(clave_json: String) -> Ensenanza:
	var normalizada: String = clave_json.strip_edges().to_lower()
	if normalizada.is_empty() or not _cache_por_clave.has(normalizada):
		return null
	return _cache_por_clave[normalizada] as Ensenanza


static func _buscar_por_id_normalizado(clave: String) -> Ensenanza:
	if _cache_por_id.has(clave):
		return _cache_por_id[clave] as Ensenanza
	if not clave.begins_with("celiaquia_"):
		return null
	var sufijo: String = clave.trim_prefix("celiaquia_")
	if not sufijo.is_valid_int():
		return null
	var id_padded: String = "celiaquia_%03d" % int(sufijo)
	if _cache_por_id.has(id_padded):
		return _cache_por_id[id_padded] as Ensenanza
	return null


static func resolver_por_teaching_key(teaching_key: String) -> Ensenanza:
	_asegurar_carga()
	var clave: String = teaching_key.strip_edges().to_lower()
	if clave.is_empty():
		return null

	var por_clave: Ensenanza = _buscar_por_clave_json(clave)
	if por_clave != null:
		return por_clave

	var por_id: Ensenanza = _buscar_por_id_normalizado(clave)
	if por_id != null:
		return por_id

	if LEGACY_TEACHING_KEY_ALIASES.has(clave):
		var alias_legacy: Ensenanza = _buscar_por_clave_json(
			str(LEGACY_TEACHING_KEY_ALIASES[clave])
		)
		if alias_legacy != null:
			return alias_legacy

	if clave.begins_with("celiaquia_"):
		var alias: Ensenanza = _buscar_por_clave_json(
			"ensenanza_%s" % clave.trim_prefix("celiaquia_")
		)
		if alias != null:
			return alias

	return null


static func resolver_ruta_imagen(teaching_key: String) -> String:
	var ensenanza: Ensenanza = resolver_por_teaching_key(teaching_key)
	if ensenanza == null:
		return ""
	return ensenanza.imagen.strip_edges()


static func resolver_texto_cierre(teaching_key: String) -> String:
	var ensenanza: Ensenanza = resolver_por_teaching_key(teaching_key)
	if ensenanza == null:
		return ""
	if not ensenanza.titulo.is_empty() and not ensenanza.texto.is_empty():
		return "%s\n\n%s" % [ensenanza.titulo, ensenanza.texto]
	if not ensenanza.texto.is_empty():
		return ensenanza.texto
	return ensenanza.titulo


static func cargar() -> Array[Ensenanza]:
	_asegurar_carga()
	var resultado: Array[Ensenanza] = []
	for clave in _cache_por_clave.keys():
		resultado.append(_cache_por_clave[clave] as Ensenanza)
	return resultado
