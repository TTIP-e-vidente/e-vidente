extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")

const SESSION_KEY_NODE_KEY := "node_key"
const SESSION_KEY_NODE_TITLE := "node_title"
const SESSION_KEY_JSON_PATH := "json_path"
const SESSION_KEY_TRACK_KEY := "track_key"
const SESSION_KEY_MODE := "mode"
const SESSION_KEY_LEVEL_NUMBER := "level_number"
const SESSION_KEY_RETURN_TO := "return_to"

const SCENE_PATH_BY_MODE := {
	NodeContentLoaderScript.MODE_QUIZ_CHOICE: GameSceneRouter.QUESTIONS_SCENE_PATH,
	NodeContentLoaderScript.MODE_DRAG_DROP: "res://niveles/nivel_1/Level.tscn",
}


# Puente simple entre un nodo del mapa y la escena jugable.
# Flujo nuevo: usar node_data.mode, guardar una sesion minima en Global
# y abrir la escena correcta. El fallback que lee el JSON solo existe
# para mapas legacy que todavia no guardan mode en el mapa.


static func open_node(
	tree: SceneTree,
	node_data: MapNodeData,
	return_to: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	if tree == null:
		return _error("No se pudo abrir el nodo: falta SceneTree.")
	if node_data == null or not node_data.is_valid():
		return _error("No se pudo abrir el nodo seleccionado.")

	var mode_result: Dictionary = _resolve_mode_for_routing(node_data)
	if not bool(mode_result.get("ok", false)):
		return mode_result

	var mode: String = str(mode_result.get("data", "")).strip_edges()
	var scene_path: String = get_playable_scene_path(mode)
	if scene_path.is_empty():
		return _error("No existe escena para el modo: %s" % mode)

	Global.establecer_sesion_nodo_jugable_activo(
		build_playable_session(node_data, return_to, mode)
	)
	_open_scene(tree, scene_path)
	return _ok()


static func build_playable_session(
	node_data: MapNodeData,
	return_to: String,
	mode: String = ""
) -> Dictionary:
	var clean_mode: String = mode.strip_edges()
	var level_number: int = node_data.index + 1
	var session_state := {
		SESSION_KEY_NODE_KEY: node_data.node_key,
		SESSION_KEY_NODE_TITLE: node_data.title,
		SESSION_KEY_JSON_PATH: node_data.json_path,
		SESSION_KEY_TRACK_KEY: node_data.track_key,
		SESSION_KEY_MODE: clean_mode,
		SESSION_KEY_LEVEL_NUMBER: level_number,
		SESSION_KEY_RETURN_TO: return_to.strip_edges(),
	}

	# El camino feliz solo emite claves nuevas y claras.
	# Los aliases legacy siguen aceptados por algunos consumidores al leer sesiones viejas.
	return session_state


static func get_playable_scene_path(mode: String) -> String:
	return str(SCENE_PATH_BY_MODE.get(mode.strip_edges(), "")).strip_edges()


static func obtener_escena_jugable(modo: String) -> String:
	return get_playable_scene_path(modo)


static func _resolve_mode_for_routing(node_data: MapNodeData) -> Dictionary:
	var map_mode: String = node_data.mode.strip_edges()
	if not map_mode.is_empty():
		return {"ok": true, "error": "", "data": map_mode}

	# Compatibilidad: mapas viejos no tenian mode y obligaban a leer el JSON del nodo.
	return _read_node_mode_from_json(node_data)


static func _read_node_mode_from_json(node_data: MapNodeData) -> Dictionary:
	var result: Dictionary = NodeContentLoaderScript.load_node_content(node_data.json_path)
	if not bool(result.get("ok", false)):
		return _error(str(result.get("error", "No se pudo cargar el nodo.")))

	var level_data: Dictionary = result.get("data", {})
	var mode: String = str(level_data.get("mode", "")).strip_edges()
	if mode.is_empty():
		return _error("El nodo no define mode.")
	return {"ok": true, "error": "", "data": mode}


static func _open_scene(tree: SceneTree, scene_path: String) -> void:
	if scene_path == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(tree)
		return
	tree.change_scene_to_file(scene_path)


static func _ok() -> Dictionary:
	return {"ok": true, "error": "", "data": {}}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "data": {}}
