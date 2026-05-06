extends "res://mapas/logica/AvanceDeNodo.gd"

const AvanceDeNodoScript := preload("res://mapas/logica/AvanceDeNodo.gd")

static func get_node_state(nodos_mapa: Array, node_data: MapNodeData) -> Dictionary:
	return AvanceDeNodoScript.get_node_state(nodos_mapa, node_data)


static func is_node_completed(node_data: MapNodeData) -> bool:
	return AvanceDeNodoScript.is_node_completed(node_data)


static func is_node_unlocked(
	nodos_mapa: Array,
	node_data: MapNodeData,
	esta_completado: bool = false
) -> bool:
	return AvanceDeNodoScript.is_node_unlocked(nodos_mapa, node_data, esta_completado)


static func get_visual_state(is_unlocked: bool, is_completed: bool) -> String:
	return AvanceDeNodoScript.get_visual_state(is_unlocked, is_completed)


static func obtener_indice_nodo(nodos_mapa: Array, node_key_actual: String) -> int:
	return AvanceDeNodoScript.obtener_indice_nodo(nodos_mapa, node_key_actual)


static func obtener_siguiente_nodo(nodos_mapa: Array, node_key_actual: String) -> Variant:
	return AvanceDeNodoScript.obtener_siguiente_nodo(nodos_mapa, node_key_actual)


static func nodo_esta_desbloqueado(
	nodos_mapa: Array,
	indice: int,
	track_key: String,
	esta_completado: bool
) -> bool:
	return AvanceDeNodoScript.nodo_esta_desbloqueado(
		nodos_mapa,
		indice,
		track_key,
		esta_completado
	)


static func mapa_esta_completado(nodos_mapa: Array, track_key: String) -> bool:
	return AvanceDeNodoScript.mapa_esta_completado(nodos_mapa, track_key)


static func can_play_node(nodos_mapa: Array, node_data: MapNodeData) -> bool:
	return AvanceDeNodoScript.can_play_node(nodos_mapa, node_data)
