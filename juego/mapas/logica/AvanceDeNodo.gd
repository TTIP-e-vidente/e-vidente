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


static func construir_estados_mapa(
	nodos_mapa: Array,
	node_progress: Dictionary = {}
) -> Array[Dictionary]:
	var node_states: Array[Dictionary] = []
	for node_data in nodos_mapa:
		if node_data is MapNodeData:
			var state: Dictionary = obtener_estado_nodo(nodos_mapa, node_data as MapNodeData)
			var saved: Dictionary = _progreso_guardado(node_progress, (node_data as MapNodeData).node_key)
			if not saved.is_empty():
				fusionar_progreso_guardado(state, saved)
			node_states.append(state)
	aplicar_reglas_secuenciales(node_states)
	return node_states


static func fusionar_progreso_guardado(state: Dictionary, saved: Dictionary) -> void:
	state["best_percent"] = float(saved.get("best_percent", 0.0))
	var fallback_accuracy: float = float(saved.get("best_percent", 0.0)) * 100.0
	state["best_accuracy"] = float(saved.get("best_accuracy", fallback_accuracy))
	if not bool(saved.get("completed", false)):
		return
	state["is_completed"] = true
	state["visual_state"] = STATE_COMPLETED
	state["state"] = STATE_COMPLETED


static func aplicar_reglas_secuenciales(node_states: Array[Dictionary]) -> void:
	var indice_recomendado := -1
	var anterior_completado := true
	for index in range(node_states.size()):
		var state: Dictionary = node_states[index]
		var raw_completado := bool(state.get("is_completed", false))
		var completado := raw_completado and anterior_completado
		if raw_completado and not completado:
			state["is_completed"] = false
			state["state"] = STATE_LOCKED
			state["visual_state"] = STATE_LOCKED
		var desbloqueado := anterior_completado
		state["is_unlocked"] = desbloqueado
		state["can_play"] = desbloqueado or completado
		if not completado:
			if anterior_completado:
				state["visual_state"] = STATE_AVAILABLE
				state["state"] = STATE_AVAILABLE
			else:
				state["visual_state"] = STATE_LOCKED
				state["state"] = STATE_LOCKED
		anterior_completado = completado
		if indice_recomendado < 0 and desbloqueado and not completado:
			indice_recomendado = index

	for index in range(node_states.size()):
		node_states[index]["is_recommended"] = index == indice_recomendado


static func puede_abrir_nodo(
	nodos_mapa: Array,
	node_data: MapNodeData,
	node_states: Array[Dictionary] = []
) -> bool:
	if node_data == null:
		return false
	var indice: int = obtener_indice_nodo(nodos_mapa, node_data.node_key)
	if indice < 0:
		return false
	var estados: Array[Dictionary] = node_states
	if estados.is_empty() or indice >= estados.size():
		estados = construir_estados_mapa(nodos_mapa, _obtener_progreso_nodos_guardado())
	if indice >= estados.size():
		return false
	return bool(estados[indice].get("can_play", false))


static func estado_en_indice(
	node_states: Array[Dictionary],
	indice: int
) -> Dictionary:
	if indice < 0 or indice >= node_states.size():
		return {}
	return node_states[indice]


static func obtener_clave_nodo_recomendado(
	nodos_mapa: Array,
	node_states: Array[Dictionary]
) -> String:
	for index in range(mini(nodos_mapa.size(), node_states.size())):
		if not bool(node_states[index].get("is_recommended", false)):
			continue
		return _obtener_node_key(nodos_mapa[index])
	return ""


static func progreso_guardado_para_clave(node_progress: Dictionary, node_key: String) -> Dictionary:
	return _progreso_guardado(node_progress, node_key)


static func _progreso_guardado(node_progress: Dictionary, node_key: String) -> Dictionary:
	var key: String = node_key.strip_edges()
	if key.is_empty() or not node_progress.has(key):
		return {}
	var np: Variant = node_progress[key]
	return np as Dictionary if np is Dictionary else {}


static func _obtener_progreso_nodos_guardado() -> Dictionary:
	if not Engine.get_main_loop() is SceneTree:
		return {}
	var save_manager: Node = (
		(Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/SaveManager")
	)
	if save_manager != null and save_manager.has_method("obtener_todo_progreso_nodos"):
		var raw: Variant = save_manager.call("obtener_todo_progreso_nodos")
		return raw as Dictionary if raw is Dictionary else {}
	return {}


static func _estado(desbloqueado: bool, completado: bool, nombre_estado: String) -> Dictionary:
	return {
		"is_unlocked": desbloqueado,
		"is_completed": completado,
		"can_play": desbloqueado or completado,
		"state": nombre_estado,
		"visual_state": nombre_estado,
		"is_recommended": false,
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
