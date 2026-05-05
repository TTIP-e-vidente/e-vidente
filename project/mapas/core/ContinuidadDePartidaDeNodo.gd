extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")


# Continuidad de la partida
static func continuar_o_finalizar_partida(
	tree: SceneTree,
	antes_de_abrir_siguiente_juego: Callable = Callable(),
	al_finalizar_partida: Callable = Callable()
) -> bool:
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return false

	if bool(estado_global.call("hay_siguiente_juego_de_partida")):
		if antes_de_abrir_siguiente_juego.is_valid():
			antes_de_abrir_siguiente_juego.call()
		estado_global.call("avanzar_partida_de_nodo")
		return abrir_juego_actual(tree, estado_global)

	estado_global.call("finalizar_partida_de_nodo")
	if al_finalizar_partida.is_valid():
		al_finalizar_partida.call()
	return false


static func hay_siguiente_juego(tree: SceneTree) -> bool:
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return false
	return bool(estado_global.call("hay_siguiente_juego_de_partida"))


static func abrir_juego_actual(tree: SceneTree, estado_global: Node = null) -> bool:
	var estado: Node = estado_global
	if estado == null:
		estado = _obtener_estado_global(tree)
	if estado == null:
		return false

	var juego_actual: Dictionary = estado.call("obtener_juego_actual_de_partida")
	var modo_actual: String = str(juego_actual.get("mode", "")).strip_edges()
	if not _es_modo_jugable_soportado(modo_actual):
		return false

	GameSceneRouter.ir_a_modo_jugable(tree, modo_actual)
	return true


# Helpers privados
static func _es_modo_jugable_soportado(modo: String) -> bool:
	match modo.strip_edges():
		"drag_drop", "quiz_choice":
			return true
		_:
			return false


static func _obtener_estado_global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")