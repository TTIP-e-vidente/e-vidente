extends RefCounted
class_name AbridorDeNodoJugable

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ContinuidadDePartidaDeNodoScript := preload("res://mapas/logica/ContinuidadDePartidaDeNodo.gd")
const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")

const CLAVE_SESION_NODE_KEY := "node_key"
const CLAVE_SESION_NODE_TITLE := "node_title"
const CLAVE_SESION_JSON_PATH := "json_path"
const CLAVE_SESION_TRACK_KEY := "track_key"
const CLAVE_SESION_MODE := "mode"
const CLAVE_SESION_LEVEL_NUMBER := "level_number"
const CLAVE_SESION_DIFFICULTY := "difficulty"
const CLAVE_SESION_RETURN_TO := "return_to"
const LOG_PREFIX := "[NODO]"


# Apertura del nodo
static func abrir_nodo(
	tree: SceneTree,
	node_data: MapNodeData,
	ruta_retorno: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	if tree == null:
		return _resultado_con_error("No se pudo abrir el nodo: falta SceneTree.")
	if node_data == null or not node_data.is_valid():
		return _resultado_con_error("No se pudo abrir el nodo seleccionado.")
	var estado_global: Node = _obtener_estado_global(tree)
	if estado_global == null:
		return _resultado_con_error("No se encontro el autoload Global.")

	var ruta_retorno_segura: String = _normalizar_ruta_de_retorno(ruta_retorno)
	var datos_de_apertura: Dictionary = _construir_datos_de_apertura(
		node_data,
		ruta_retorno_segura
	)
	if datos_de_apertura.is_empty():
		_limpiar_estado_de_apertura(estado_global)
		return _resultado_con_error("No se pudo armar la partida del nodo.")

	print(
		LOG_PREFIX,
		" abrir_nodo=",
		node_data.node_key,
		" mode=",
		node_data.mode,
		" return_to=",
		ruta_retorno_segura
	)
	_iniciar_partida_en_global(estado_global, datos_de_apertura)

	if not ContinuidadDePartidaDeNodoScript.abrir_juego_actual(tree, estado_global):
		_limpiar_estado_de_apertura(estado_global)
		return _resultado_con_error("No se pudo abrir el primer juego del nodo.")

	return _resultado_ok()


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


# Helpers privados
static func _normalizar_ruta_de_retorno(ruta_retorno: String) -> String:
	var ruta_retorno_segura: String = ruta_retorno.strip_edges()
	if ruta_retorno_segura.is_empty():
		return GameSceneRouter.MAP_SCENE_PATH
	return ruta_retorno_segura


static func _construir_datos_de_apertura(
	node_data: MapNodeData,
	ruta_retorno: String
) -> Dictionary:
	var sesion_jugable: Dictionary = construir_sesion_jugable(node_data, ruta_retorno)
	var plan_de_partida: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(node_data)
	if plan_de_partida.is_empty():
		return {}
	plan_de_partida["escena_de_retorno"] = ruta_retorno
	print(
		LOG_PREFIX,
		" plan_nodo=",
		node_data.node_key,
		" juegos=",
		int(plan_de_partida.get("total_juegos", 0))
	)
	return {
		"sesion_jugable": sesion_jugable,
		"plan_de_partida": plan_de_partida,
	}


static func _iniciar_partida_en_global(estado_global: Node, datos_de_apertura: Dictionary) -> void:
	_limpiar_estado_de_apertura(estado_global)
	estado_global.call(
		"establecer_sesion_nodo_jugable_activo",
		datos_de_apertura.get("sesion_jugable", {})
	)
	estado_global.call("iniciar_partida_de_nodo", datos_de_apertura.get("plan_de_partida", {}))


static func _limpiar_estado_de_apertura(estado_global: Node) -> void:
	if estado_global == null:
		return
	estado_global.call("finalizar_partida_de_nodo")
	estado_global.call("limpiar_sesion_nodo_jugable_activo")


static func _obtener_estado_global(tree: SceneTree) -> Node:
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Global")

static func _resultado_ok() -> Dictionary:
	return {"ok": true, "error": "", "data": {}}


static func _resultado_con_error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
