extends "res://mapas/logica/AbridorDeNodoJugable.gd"

const AbridorDeNodoJugableScript := preload("res://mapas/logica/AbridorDeNodoJugable.gd")

static func abrir_nodo(
	tree: SceneTree,
	node_data: MapNodeData,
	ruta_retorno: String = "res://mapas/MapScene.tscn"
) -> Dictionary:
	return AbridorDeNodoJugableScript.abrir_nodo(tree, node_data, ruta_retorno)


static func construir_sesion_jugable(
	node_data: MapNodeData,
	ruta_retorno: String
) -> Dictionary:
	return AbridorDeNodoJugableScript.construir_sesion_jugable(node_data, ruta_retorno)
