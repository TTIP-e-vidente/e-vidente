extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const PlanDeCorridaDeNodoScript := preload("res://mapas/core/PlanDeCorridaDeNodo.gd")

const CLAVE_SESION_NODE_KEY := "node_key"
const CLAVE_SESION_NODE_TITLE := "node_title"
const CLAVE_SESION_JSON_PATH := "json_path"
const CLAVE_SESION_TRACK_KEY := "track_key"
const CLAVE_SESION_MODE := "mode"
const CLAVE_SESION_LEVEL_NUMBER := "level_number"
const CLAVE_SESION_DIFFICULTY := "difficulty"
const CLAVE_SESION_RETURN_TO := "return_to"

const RUTA_ESCENA_POR_MODO := {
	MapNodeDataScript.MODE_QUIZ_CHOICE: GameSceneRouter.QUESTIONS_SCENE_PATH,
	MapNodeDataScript.MODE_DRAG_DROP: GameSceneRouter.LEVEL_SCENE_PATH,
}

static func open_node(
	tree: SceneTree,
	node_data: MapNodeData,
	ruta_retorno: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	return abrir_nodo(tree, node_data, ruta_retorno)


static func abrir_nodo(
	tree: SceneTree,
	node_data: MapNodeData,
	ruta_retorno: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	if tree == null:
		return _error("No se pudo abrir el nodo: falta SceneTree.")
	if node_data == null or not node_data.is_valid():
		return _error("No se pudo abrir el nodo seleccionado.")
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return _error("No se encontro el autoload Global.")

	var modo: String = node_data.mode.strip_edges()
	var ruta_escena: String = obtener_ruta_escena_jugable(modo)
	if ruta_escena.is_empty():
		return _error("No existe escena para el modo: %s" % modo)

	var ruta_retorno_segura: String = ruta_retorno.strip_edges()
	if ruta_retorno_segura.is_empty():
		ruta_retorno_segura = GameSceneRouter.MAP_SCENE_PATH

	estado_global.call("finalizar_corrida_de_nodo")
	estado_global.call(
		"establecer_sesion_nodo_jugable_activo",
		construir_sesion_jugable(node_data, ruta_retorno_segura)
	)
	var plan_de_corrida: Dictionary = PlanDeCorridaDeNodoScript.construir_plan_de_corrida(node_data)
	if plan_de_corrida.is_empty():
		return _error("No se pudo armar la corrida del nodo.")
	plan_de_corrida["escena_de_retorno"] = ruta_retorno_segura
	estado_global.call("iniciar_corrida_de_nodo", plan_de_corrida)

	var juego_actual: Dictionary = estado_global.call("obtener_juego_actual_del_nodo")
	var ruta_escena_actual: String = obtener_ruta_escena_jugable(
		str(juego_actual.get("mode", "")).strip_edges()
	)
	if ruta_escena_actual.is_empty():
		estado_global.call("finalizar_corrida_de_nodo")
		estado_global.call("limpiar_sesion_nodo_jugable_activo")
		return _error("No existe escena para el juego actual del nodo.")

	_abrir_escena(tree, ruta_escena_actual)
	return _ok()


static func construir_sesion_jugable(
	node_data: MapNodeData,
	ruta_retorno: String
) -> Dictionary:
	var numero_nivel: int = node_data.index + 1
	var estado_sesion := {
		CLAVE_SESION_NODE_KEY: node_data.node_key,
		CLAVE_SESION_NODE_TITLE: node_data.title,
		CLAVE_SESION_JSON_PATH: node_data.json_path,
		CLAVE_SESION_TRACK_KEY: node_data.track_key,
		CLAVE_SESION_MODE: node_data.mode.strip_edges(),
		CLAVE_SESION_LEVEL_NUMBER: numero_nivel,
		CLAVE_SESION_DIFFICULTY: node_data.difficulty,
		CLAVE_SESION_RETURN_TO: ruta_retorno.strip_edges(),
	}

	# El camino feliz solo emite claves nuevas y claras.
	# Los aliases legacy siguen aceptados por algunos consumidores al leer sesiones viejas.
	return estado_sesion


static func obtener_ruta_escena_jugable(mode: String) -> String:
	return str(RUTA_ESCENA_POR_MODO.get(mode.strip_edges(), "")).strip_edges()


static func obtener_escena_jugable(modo: String) -> String:
	return obtener_ruta_escena_jugable(modo)


static func _abrir_escena(tree: SceneTree, ruta_escena: String) -> void:
	if ruta_escena == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(tree)
		return
	if ruta_escena == GameSceneRouter.LEVEL_SCENE_PATH:
		GameSceneRouter.go_to_level(tree)
		return
	tree.change_scene_to_file(ruta_escena)


static func _obtener_estado_global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")

static func _ok() -> Dictionary:
	return {"ok": true, "error": "", "data": {}}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
