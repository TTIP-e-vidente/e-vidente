class_name MapApi
extends RefCounted

const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")


static func cargar(ruta_json: String) -> Dictionary:
	return CargadorDeMapaScript.cargar_mapa(ruta_json)


static func aplicar_tablero(
		map_board: Node,
		nodos: Array,
		estados: Array,
		layout_config: Variant = null
) -> void:
	if map_board == null or not map_board.has_method("configurar_nodos"):
		return
	map_board.call("configurar_nodos", nodos, estados, layout_config)
	if map_board.has_method("actualizar_progreso_desde_guardado"):
		map_board.call("actualizar_progreso_desde_guardado")
