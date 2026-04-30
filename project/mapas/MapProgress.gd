extends RefCounted


static func obtener_indice_nodo(nodos_mapa: Array, node_key_actual: String) -> int:
	for indice in range(nodos_mapa.size()):
		var nodo_mapa: Dictionary = nodos_mapa[indice]
		if str(nodo_mapa.get("node_key", "")).strip_edges() == node_key_actual:
			return indice
	return -1


static func obtener_siguiente_nodo(nodos_mapa: Array, node_key_actual: String) -> Dictionary:
	var indice_actual: int = obtener_indice_nodo(nodos_mapa, node_key_actual)
	if indice_actual < 0:
		return {}

	var siguiente_indice: int = indice_actual + 1
	if siguiente_indice >= nodos_mapa.size():
		return {}

	return nodos_mapa[siguiente_indice]


static func nodo_esta_desbloqueado(
	nodos_mapa: Array,
	indice: int,
	track_key: String,
	esta_completado: bool
) -> bool:
	if esta_completado:
		return true
	if indice == 0:
		return true

	var nodo_anterior: Dictionary = nodos_mapa[indice - 1]
	var node_key_anterior: String = str(nodo_anterior.get("node_key", "")).strip_edges()
	return Global.es_nodo_jugable_completado(track_key, node_key_anterior)


static func mapa_esta_completado(nodos_mapa: Array, track_key: String) -> bool:
	if nodos_mapa.is_empty():
		return false

	for nodo_mapa in nodos_mapa:
		var node_key_actual: String = str(nodo_mapa.get("node_key", "")).strip_edges()
		if not Global.es_nodo_jugable_completado(track_key, node_key_actual):
			return false

	return true
