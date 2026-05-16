extends RefCounted
class_name MapFlow

# Coordina la selección de nodo en el mapa.
# No renderiza. No calcula EXP. Delega apertura en AbridorDeNodoJugable.

const AvanceDeNodo := preload("res://mapas/logica/AvanceDeNodo.gd")
const AbridorDeNodoJugable := preload("res://mapas/logica/AbridorDeNodoJugable.gd")

signal nodo_seleccionado(node_id: String)
signal nodo_bloqueado(node_id: String)
signal apertura_fallida(error: String)


func seleccionar_nodo(
	tree: SceneTree,
	nodos_mapa: Array,
	node_data: MapNodeData
) -> void:
	if node_data == null or not node_data.is_valid():
		return

	if not _nodo_esta_desbloqueado(nodos_mapa, node_data):
		nodo_bloqueado.emit(node_data.node_key)
		return

	nodo_seleccionado.emit(node_data.node_key)
	_abrir_nodo_jugable(tree, node_data)


func _nodo_esta_desbloqueado(nodos_mapa: Array, node_data: MapNodeData) -> bool:
	var estado: Dictionary = AvanceDeNodo.get_node_state(nodos_mapa, node_data)
	return bool(estado.get("is_unlocked", false))


func _abrir_nodo_jugable(tree: SceneTree, node_data: MapNodeData) -> void:
	var resultado: Dictionary = AbridorDeNodoJugable.abrir_nodo(tree, node_data)
	if not bool(resultado.get("ok", false)):
		apertura_fallida.emit(str(resultado.get("error", "No se pudo abrir el nodo.")))
