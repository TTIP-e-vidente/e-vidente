extends RefCounted
class_name FlujoDeNodoJugable

# Decide si un nodo del mapa está disponible y lo abre si corresponde.
# No renderiza. No calcula EXP. Delega la apertura en AbridorDeNodoJugable.

const AvanceDeNodoScript := preload("res://mapas/logica/AvanceDeNodo.gd")
const AbridorDeNodoJugableScript := preload("res://mapas/logica/AbridorDeNodoJugable.gd")

signal apertura_fallida(error: String)


func seleccionar_nodo(
	tree: SceneTree,
	nodos_mapa: Array,
	node_data: MapNodeData
) -> void:
	if node_data == null or not node_data.is_valid():
		return

	if not _nodo_esta_desbloqueado(nodos_mapa, node_data):
		return

	_abrir_nodo_jugable(tree, node_data)


func _nodo_esta_desbloqueado(nodos_mapa: Array, node_data: MapNodeData) -> bool:
	var estado: Dictionary = AvanceDeNodoScript.get_node_state(nodos_mapa, node_data)
	return bool(estado.get("is_unlocked", false))


func _abrir_nodo_jugable(tree: SceneTree, node_data: MapNodeData) -> void:
	var resultado: Dictionary = AbridorDeNodoJugableScript.abrir_nodo(tree, node_data)
	if not bool(resultado.get("ok", false)):
		apertura_fallida.emit(str(resultado.get("error", "No se pudo abrir el nodo.")))
