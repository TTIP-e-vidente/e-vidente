extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const MapNodeDataScript := preload("res://mapas/MapNodeData.gd")
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA


@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	_connect_back_signal()
	Global.clear_active_question_session()
	_refresh_map_nodes()


func _connect_back_signal() -> void:
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _on_back_requested)


# Render del mapa -------------------------------------------------------------
func _refresh_map_nodes() -> void:
	var playable_scene_nodes: Array[Node2D] = _get_playable_scene_nodes()
	if playable_scene_nodes.is_empty():
		push_warning("MapScene: MapBoard no expone nodos configurados en escena.")
		return

	var node_selected_handler := Callable(self, "_on_node_selected")
	var previous_node_completed: bool = true

	for scene_node in playable_scene_nodes:
		var node_data = scene_node.call("build_node_data").duplicate_data()
		var node_completed: bool = _is_node_completed(node_data)
		var node_unlocked: bool = previous_node_completed or node_completed

		scene_node.position = node_data.node_position
		scene_node.apply_node_state(node_data, node_unlocked, node_completed)
		if not scene_node.is_connected("node_selected", node_selected_handler):
			scene_node.connect("node_selected", node_selected_handler)

		previous_node_completed = node_completed


func get_playable_node_data() -> Array:
	var playable_node_data: Array = []
	for scene_node in _get_playable_scene_nodes():
		playable_node_data.append(scene_node.call("build_node_data").duplicate_data())
	return playable_node_data


func get_playable_node_definitions() -> Array[Dictionary]:
	var node_definitions: Array[Dictionary] = []
	for node_data in get_playable_node_data():
		node_definitions.append(node_data.to_dictionary())
	return node_definitions


func get_nodes_container() -> Node2D:
	if map_board != null and map_board.has_method("get_nodes_container"):
		return map_board.call("get_nodes_container") as Node2D
	return null


func _get_playable_scene_nodes() -> Array[Node2D]:
	var playable_scene_nodes: Array[Node2D] = []
	for scene_node in _get_board_nodes():
		var node_data = scene_node.call("build_node_data")
		if not _node_has_destination(node_data):
			push_warning("MapScene: Hay un nodo del mapa sin destino configurado.")
			scene_node.visible = false
			continue

		scene_node.visible = true
		playable_scene_nodes.append(scene_node)

	return playable_scene_nodes


func _get_board_nodes() -> Array[Node2D]:
	var board_nodes: Array[Node2D] = []
	if map_board == null or not map_board.has_method("get_authored_level_nodes"):
		return board_nodes

	var raw_nodes: Array = map_board.call("get_authored_level_nodes")
	for raw_node in raw_nodes:
		var map_node: Node2D = raw_node as Node2D
		if map_node != null:
			board_nodes.append(map_node)
	return board_nodes


# Navegacion -----------------------------------------------------------------
func _on_node_selected(selected_target: Variant) -> void:
	var node_data = _get_node_data_from_selection(selected_target)
	if node_data == null:
		var scene_path := str(selected_target).strip_edges()
		if scene_path.is_empty():
			push_warning("MapScene: Se intento abrir un destino vacio desde el mapa.")
			return

		get_tree().change_scene_to_file(scene_path)
		return

	var track_key: String = _get_valid_track_key(node_data)
	if node_data.is_question():
		Global.set_active_question_session(_build_question_session(track_key, node_data))
		GameSceneRouter.go_to_questions(get_tree())
		return

	GameSceneRouter.go_to_track_level(
		get_tree(),
		track_key,
		node_data.level_number
	)


func _get_node_data_from_selection(selected_target: Variant):
	if selected_target is Dictionary:
		return MapNodeDataScript.from_dictionary(selected_target as Dictionary)
	if selected_target is Object and selected_target.has_method("to_dictionary"):
		return selected_target
	return null


func _build_question_session(track_key: String, node_data) -> Dictionary:
	return {
		"track_key": track_key,
		"nivel_id": node_data.get_question_session_level_id(),
		"question_key": node_data.question_key,
		"question_resource_path": node_data.question_resource_path,
		"return_scene_path": GameSceneRouter.MAP_SCENE_PATH
	}


func _node_has_destination(node_data) -> bool:
	if node_data == null:
		return false
	if node_data.is_question():
		return node_data.has_question_destination()
	if not node_data.is_chapter():
		return false
	return node_data.has_chapter_destination() and GameTrackCatalog.has_track(
		_get_valid_track_key(node_data)
	)


# Progreso -------------------------------------------------------------------
func _is_node_completed(node_data) -> bool:
	var track_key: String = _get_valid_track_key(node_data)
	if node_data.is_question():
		return Global.is_question_completed(track_key, node_data.question_key)
	return Global.is_level_completed(track_key, node_data.level_number)


func _get_valid_track_key(node_data) -> String:
	var raw_track_key: String = node_data.get_track_key_or_default(DEFAULT_TRACK_KEY)
	if GameTrackCatalog.has_track(raw_track_key):
		return raw_track_key
	return DEFAULT_TRACK_KEY


# Salida ---------------------------------------------------------------------
func _on_back_requested() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
