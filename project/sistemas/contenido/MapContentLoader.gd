extends RefCounted
class_name MapContentLoader


static func cargar_mapa(ruta_json_mapa: String) -> Dictionary:
	var ruta_limpia: String = ruta_json_mapa.strip_edges()
	if ruta_limpia.is_empty():
		return _resultado_error("Falta la ruta del JSON del mapa.")

	if not FileAccess.file_exists(ruta_limpia):
		return _resultado_error("No existe el JSON del mapa: %s" % ruta_limpia)

	var archivo: FileAccess = FileAccess.open(ruta_limpia, FileAccess.READ)
	if archivo == null:
		return _resultado_error("No se pudo abrir el JSON del mapa: %s" % ruta_limpia)

	var parser := JSON.new()
	var resultado_parseo: Error = parser.parse(archivo.get_as_text())
	if resultado_parseo != OK:
		return _resultado_error(
			"JSON invalido en linea %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)

	var datos_crudos: Variant = parser.get_data()
	if not datos_crudos is Dictionary:
		return _resultado_error("El JSON del mapa debe ser un objeto.")

	return _validar_mapa(datos_crudos as Dictionary)


static func _validar_mapa(datos_mapa: Dictionary) -> Dictionary:
	var id_mapa: String = str(datos_mapa.get("id", "")).strip_edges()
	var track_key: String = str(datos_mapa.get("track_key", "")).strip_edges()
	var titulo: String = str(datos_mapa.get("title", "")).strip_edges()
	var nodos_crudos: Variant = datos_mapa.get("nodes", [])

	if id_mapa.is_empty():
		return _resultado_error("El mapa necesita id.")
	if track_key.is_empty():
		return _resultado_error("El mapa necesita track_key.")
	if titulo.is_empty():
		return _resultado_error("El mapa necesita title.")
	if not nodos_crudos is Array:
		return _resultado_error("El mapa necesita nodes como array.")

	var nodos: Array = []
	for indice in range((nodos_crudos as Array).size()):
		var resultado_nodo: Dictionary = _validar_nodo_mapa((nodos_crudos as Array)[indice], indice)
		if not bool(resultado_nodo.get("ok", false)):
			return resultado_nodo
		nodos.append(resultado_nodo.get("data", {}))

	return _resultado_ok(
		{
			"id": id_mapa,
			"track_key": track_key,
			"title": titulo,
			"nodes": nodos
		}
	)


static func _validar_nodo_mapa(nodo_crudo: Variant, indice: int) -> Dictionary:
	var numero_nodo: int = indice + 1
	if not nodo_crudo is Dictionary:
		return _resultado_error("El nodo %d del mapa debe ser un objeto." % numero_nodo)

	var nodo_mapa: Dictionary = nodo_crudo as Dictionary
	var node_key: String = str(nodo_mapa.get("node_key", "")).strip_edges()
	var titulo_nodo: String = str(nodo_mapa.get("title", "")).strip_edges()
	var ruta_json_nodo: String = str(nodo_mapa.get("json_path", "")).strip_edges()

	if node_key.is_empty():
		return _resultado_error("El nodo %d no tiene node_key." % numero_nodo)
	if titulo_nodo.is_empty():
		return _resultado_error("El nodo %d no tiene title." % numero_nodo)
	if ruta_json_nodo.is_empty():
		return _resultado_error("El nodo %d no tiene json_path." % numero_nodo)

	return _resultado_ok(
		{
			"node_key": node_key,
			"title": titulo_nodo,
			"json_path": ruta_json_nodo
		}
	)


static func _resultado_ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}


static func _resultado_error(error: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": error}