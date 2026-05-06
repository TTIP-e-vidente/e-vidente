extends "res://mapas/logica/ArmadorDePartida.gd"
class_name PlanDePartidaDeNodo

const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")

static func construir_plan_de_partida(node_data: MapNodeData) -> Dictionary:
	return ArmadorDePartidaScript.construir_plan_de_partida(node_data)


static func obtener_cantidad_de_juegos_para_nodo(node_index: int) -> int:
	return ArmadorDePartidaScript.obtener_cantidad_de_juegos_para_nodo(node_index)


static func construir_juegos_para_nodo(
	node_data: MapNodeData,
	total_juegos: int
) -> Array[Dictionary]:
	return ArmadorDePartidaScript.construir_juegos_para_nodo(node_data, total_juegos)


static func obtener_dificultad_base_del_nodo(node_data: MapNodeData) -> int:
	return ArmadorDePartidaScript.obtener_dificultad_base_del_nodo(node_data)


static func obtener_dificultad_para_juego(node_data: MapNodeData, indice_juego: int) -> int:
	return ArmadorDePartidaScript.obtener_dificultad_para_juego(node_data, indice_juego)
