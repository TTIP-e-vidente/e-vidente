extends RefCounted

const STATE_COMPLETED := "completed"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"


static func get_node_state(nodos_mapa: Array, node_data: MapNodeData) -> Dictionary:
	if node_data == null:
		return _state(false, false, STATE_LOCKED)

	var completed: bool = is_node_completed(node_data)
	var unlocked: bool = is_node_unlocked(nodos_mapa, node_data, completed)
	return _state(unlocked, completed, get_visual_state(unlocked, completed))


static func is_node_completed(node_data: MapNodeData) -> bool:
	if node_data == null:
		return false
	return Global.es_nodo_jugable_completado(node_data.track_key, node_data.node_key)


static func is_node_unlocked(
	nodos_mapa: Array,
	node_data: MapNodeData,
	esta_completado: bool = false
) -> bool:
	if node_data == null:
		return false
	var index: int = obtener_indice_nodo(nodos_mapa, node_data.node_key)
	if index < 0:
		index = node_data.index
	return nodo_esta_desbloqueado(nodos_mapa, index, node_data.track_key, esta_completado)


static func get_visual_state(is_unlocked: bool, is_completed: bool) -> String:
	if is_completed:
		return STATE_COMPLETED
	if is_unlocked:
		return STATE_AVAILABLE
	return STATE_LOCKED


static func obtener_indice_nodo(nodos_mapa: Array, node_key_actual: String) -> int:
	for indice in range(nodos_mapa.size()):
		if _obtener_node_key(nodos_mapa[indice]) == node_key_actual.strip_edges():
			return indice
	return -1


static func obtener_siguiente_nodo(nodos_mapa: Array, node_key_actual: String) -> Variant:
	var indice_actual: int = obtener_indice_nodo(nodos_mapa, node_key_actual)
	if indice_actual < 0:
		return null

	var siguiente_indice: int = indice_actual + 1
	if siguiente_indice >= nodos_mapa.size():
		return null

	return nodos_mapa[siguiente_indice]


static func nodo_esta_desbloqueado(
	nodos_mapa: Array,
	indice: int,
	track_key: String,
	esta_completado: bool
) -> bool:
	if esta_completado:
		return true
	if indice < 0 or indice >= nodos_mapa.size():
		return false
	if indice == 0:
		return true

	var node_key_anterior: String = _obtener_node_key(nodos_mapa[indice - 1])
	return Global.es_nodo_jugable_completado(track_key, node_key_anterior)


static func mapa_esta_completado(nodos_mapa: Array, track_key: String) -> bool:
	if nodos_mapa.is_empty():
		return false

	for nodo_mapa in nodos_mapa:
		var node_key_actual: String = _obtener_node_key(nodo_mapa)
		if not Global.es_nodo_jugable_completado(track_key, node_key_actual):
			return false

	return true


static func can_play_node(nodos_mapa: Array, node_data: MapNodeData) -> bool:
	var state := get_node_state(nodos_mapa, node_data)
	return bool(state.get("can_play", false))


static func _state(is_unlocked: bool, is_completed: bool, state_name: String) -> Dictionary:
	return {
		"is_unlocked": is_unlocked,
		"is_completed": is_completed,
		"can_play": is_unlocked or is_completed,
		"state": state_name,
		"visual_state": state_name,
	}


static func _obtener_node_key(nodo_mapa: Variant) -> String:
	if nodo_mapa is MapNodeData:
		return (nodo_mapa as MapNodeData).node_key.strip_edges()
	if nodo_mapa is Dictionary:
		return str((nodo_mapa as Dictionary).get("node_key", "")).strip_edges()
	return ""
