extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")

const RUTAS_POR_MODO := {
	NodeContentLoaderScript.MODE_QUIZ_CHOICE: GameSceneRouter.QUESTIONS_SCENE_PATH,
	NodeContentLoaderScript.MODE_DRAG_DROP: "res://niveles/nivel_1/Level.tscn",
}


static func open_node(
	tree: SceneTree,
	node_data: MapNodeData,
	return_to: String = GameSceneRouter.MAP_SCENE_PATH
) -> Dictionary:
	if tree == null:
		return _error("No se pudo abrir el nodo: falta SceneTree.")
	if node_data == null or not node_data.is_valid():
		return _error("No se pudo abrir el nodo seleccionado.")

	var mode_result: Dictionary = _resolve_node_mode(node_data)
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
	return {
		"node_key": node_data.node_key,
		"node_title": node_data.title,
		"json_path": node_data.json_path,
		"track_key": node_data.track_key,
		"nivel_id": node_data.index + 1,
		"node_mode": mode.strip_edges(),
		"return_to": return_to.strip_edges(),
	}


static func get_playable_scene_path(mode: String) -> String:
	return str(RUTAS_POR_MODO.get(mode.strip_edges(), "")).strip_edges()


static func obtener_escena_jugable(modo: String) -> String:
	return get_playable_scene_path(modo)


static func _resolve_node_mode(node_data: MapNodeData) -> Dictionary:
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
