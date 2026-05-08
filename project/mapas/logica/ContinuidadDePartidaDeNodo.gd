extends RefCounted
class_name ContinuidadDePartidaDeNodo

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const LOG_PREFIX := "[AVANCE_NODO]"
const LOG_PREFIX_NODE_PROGRESS := "[NodeProgress]"
const LOG_PREFIX_NODE_COMPLETE := "[NodeComplete]"


# Decide si abrir el siguiente juego del plan o cerrar el nodo actual.
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
		print(LOG_PREFIX, " continuar=siguiente_juego")
		return abrir_juego_actual(tree, estado_global)

	var partida_actual: Dictionary = estado_global.call("obtener_partida_de_nodo_actual")
	print(
		"%s node=%s"
		% [LOG_PREFIX_NODE_COMPLETE, str(partida_actual.get("clave_nodo", "")).strip_edges()]
	)
	print(LOG_PREFIX, " continuar=finalizar_partida")
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
	# Abre el juego actual ya armado por el plan; no altera el orden del nodo.
	var estado: Node = estado_global
	if estado == null:
		estado = _obtener_estado_global(tree)
	if estado == null:
		return false

	var juego_actual: Dictionary = estado.call("obtener_juego_actual_de_partida")
	var partida_actual: Dictionary = estado.call("obtener_partida_de_nodo_actual")
	var modo_actual: String = str(juego_actual.get("mode", "")).strip_edges()
	if not _es_modo_jugable_soportado(modo_actual):
		push_error(
			"ContinuidadDePartidaDeNodo: modo no soportado: %s"
			% JSON.stringify(juego_actual)
		)
		return false

	print(
		"%s game=%d/%d activity=%s"
		% [
			LOG_PREFIX_NODE_PROGRESS,
			int(partida_actual.get("indice_juego_actual", 0)) + 1,
			int(partida_actual.get("total_juegos", 0)),
			_resolver_identificador_de_juego(juego_actual),
		]
	)
	GameSceneRouter.ir_a_modo_jugable(tree, modo_actual)
	return true


# Helpers privados
static func _es_modo_jugable_soportado(modo: String) -> bool:
	match modo.strip_edges():
		"drag_drop", "quiz_choice", "vinculacion_conceptos":
			return true
		_:
			return false


static func _obtener_estado_global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")


static func _resolver_identificador_de_juego(juego_actual: Dictionary) -> String:
	var activity_id: String = str(juego_actual.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		return activity_id
	var json_path: String = str(juego_actual.get("json_path", "")).strip_edges()
	if not json_path.is_empty():
		return json_path.get_file().trim_suffix(".json")
	return str(juego_actual.get("clave_nodo_de_origen", "")).strip_edges()
