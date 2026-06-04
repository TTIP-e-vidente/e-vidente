# Determina si el nodo avanza al siguiente juego o finaliza la partida.
extends RefCounted
class_name AvanceDeNodo

const STATE_COMPLETED := "completed"
const STATE_AVAILABLE := "available"
const STATE_LOCKED := "locked"


# Solo consulta el progreso ya guardado; no abre escenas ni arma partidas.
static func obtener_estado_nodo(nodos_mapa: Array, node_data: MapNodeData) -> Dictionary:
	if node_data == null:
		return _estado(false, false, STATE_LOCKED)

	var completed: bool = nodo_esta_completado(node_data)
	var unlocked: bool = nodo_esta_desbloqueado_por_progreso(nodos_mapa, node_data, completed)
	return _estado(unlocked, completed, obtener_estado_visual(unlocked, completed))


static func nodo_esta_completado(node_data: MapNodeData) -> bool:
	if node_data == null:
		return false
	var g := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Global") if Engine.get_main_loop() is SceneTree else null
	if g == null:
		return false
	return g.call("es_nodo_jugable_completado", node_data.track_key, node_data.node_key)


static func nodo_esta_desbloqueado_por_progreso(
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


static func obtener_estado_visual(desbloqueado: bool, completado: bool) -> String:
	if completado:
		return STATE_COMPLETED
	if desbloqueado:
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


static func hay_siguiente_juego(plan_de_partida: Dictionary) -> bool:
	# Lee el plan actual y responde si queda otro juego dentro del mismo nodo.
	var total_juegos: int = _obtener_total_juegos_plan(plan_de_partida)
	var indice_actual: int = int(plan_de_partida.get("indice_juego_actual", 0))
	return indice_actual >= 0 and indice_actual + 1 < total_juegos


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
	var g := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Global") if Engine.get_main_loop() is SceneTree else null
	if g == null:
		return false
	return g.call("es_nodo_jugable_completado", track_key, node_key_anterior)


static func mapa_esta_completado(nodos_mapa: Array, track_key: String) -> bool:
	if nodos_mapa.is_empty():
		return false
	var g := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Global") if Engine.get_main_loop() is SceneTree else null
	if g == null:
		return false

	var total: int = nodos_mapa.size()
	var completed_count: int = 0
	for nodo_mapa in nodos_mapa:
		var node_key_actual: String = _obtener_node_key(nodo_mapa)
		if g.call("es_nodo_jugable_completado", track_key, node_key_actual):
			completed_count += 1
		else:
			print(
				"[MapCompletion] checking map_id=\"", track_key,
				"\" completed=", completed_count, "/", total,
				" missing=\"", node_key_actual, "\""
			)
			return false

	print(
		"[MapCompletion] checking map_id=\"", track_key,
		"\" completed=", completed_count, "/", total, " -> COMPLETE"
	)
	return true


static func _estado(desbloqueado: bool, completado: bool, nombre_estado: String) -> Dictionary:
	return {
		"is_unlocked": desbloqueado,
		"is_completed": completado,
		"can_play": desbloqueado or completado,
		"state": nombre_estado,
		"visual_state": nombre_estado,
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
		return 0
	return juegos.size()
