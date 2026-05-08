extends RefCounted
class_name AvanceDeNodo

const STATE_COMPLETED := "completed"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"
const LOG_PREFIX := "[AVANCE_NODO]"


# Solo consulta el progreso ya guardado; no abre escenas ni arma partidas.
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
	if node_data.default_unlocked:
		return true
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
		print(LOG_PREFIX, " siguiente_nodo=false node_key_no_encontrado=", node_key_actual)
		return null

	var siguiente_indice: int = indice_actual + 1
	if siguiente_indice >= nodos_mapa.size():
		print(
			LOG_PREFIX,
			" siguiente_nodo=false indice_actual=",
			indice_actual,
			" total=",
			nodos_mapa.size()
		)
		return null

	print(
		LOG_PREFIX,
		" siguiente_nodo=true indice_actual=",
		indice_actual,
		" siguiente=",
		siguiente_indice
	)
	return nodos_mapa[siguiente_indice]


static func hay_siguiente_juego(plan_de_partida: Dictionary) -> bool:
	# Lee el plan actual y responde si queda otro juego dentro del mismo nodo.
	var total_juegos: int = _obtener_total_juegos_plan(plan_de_partida)
	var indice_actual: int = int(plan_de_partida.get("indice_juego_actual", 0))
	var hay_siguiente: bool = indice_actual >= 0 and indice_actual + 1 < total_juegos
	print(
		LOG_PREFIX,
		" indice_actual=", indice_actual,
		" total=", total_juegos,
		" hay_siguiente=", hay_siguiente
	)
	return hay_siguiente


static func obtener_siguiente_juego(plan_de_partida: Dictionary) -> Dictionary:
	if not hay_siguiente_juego(plan_de_partida):
		return {}
	var juegos: Array[Dictionary] = _obtener_juegos_plan(plan_de_partida)
	var siguiente_indice: int = int(plan_de_partida.get("indice_juego_actual", 0)) + 1
	return juegos[siguiente_indice].duplicate(true)


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


static func _obtener_juegos_plan(plan_de_partida: Dictionary) -> Array[Dictionary]:
	var juegos: Array[Dictionary] = []
	var raw_juegos: Variant = plan_de_partida.get("juegos", [])
	if not raw_juegos is Array:
		return juegos
	for raw_juego in raw_juegos as Array:
		if raw_juego is Dictionary:
			juegos.append((raw_juego as Dictionary).duplicate(true))
	return juegos


static func _obtener_total_juegos_plan(plan_de_partida: Dictionary) -> int:
	var juegos: Array[Dictionary] = _obtener_juegos_plan(plan_de_partida)
	if juegos.is_empty():
		print(LOG_PREFIX, " plan invalido: juegos vacios")
		return 0
	return juegos.size()
