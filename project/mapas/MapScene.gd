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
	var board_nodes: Array[Node2D] = _get_board_nodes()
	if board_nodes.is_empty():
		push_warning("MapScene: MapBoard no expone nodos configurados en escena.")
		return

	var playable_entries: Array[Dictionary] = _build_playable_entries(board_nodes)
	var playable_node_data: Array = _collect_node_data(playable_entries)
	var node_selected_handler := Callable(self, "_on_node_selected")

	for node_index in range(playable_entries.size()):
		_apply_progress_to_node(
			playable_entries[node_index],
			playable_node_data,
			node_index,
			node_selected_handler
		)


func get_playable_node_data() -> Array:
	var board_nodes: Array[Node2D] = _get_board_nodes()
	var playable_entries: Array[Dictionary] = _build_playable_entries(board_nodes)
	return _collect_node_data(playable_entries)


func get_playable_node_definitions() -> Array[Dictionary]:
	var node_definitions: Array[Dictionary] = []
	for node_data in get_playable_node_data():
		node_definitions.append(node_data.to_dictionary())
	return node_definitions

func get_nodes_container() -> Node2D:
	if map_board != null and map_board.has_method("get_nodes_container"):
		return map_board.call("get_nodes_container") as Node2D
	return null


func _build_playable_entries(scene_nodes: Array[Node2D]) -> Array[Dictionary]:
	var playable_entries: Array[Dictionary] = []
	for scene_node in scene_nodes:
		var node_data = scene_node.call("build_node_data")
		if not _node_has_destination(node_data):
			push_warning("MapScene: Hay un nodo del mapa sin destino configurado.")
			scene_node.visible = false
			continue

		scene_node.visible = true
		playable_entries.append({
			"scene_node": scene_node,
			"node_data": node_data.duplicate_data()
		})

	return playable_entries


func _collect_node_data(playable_entries: Array[Dictionary]) -> Array:
	var node_data_list: Array = []
	for entry in playable_entries:
		node_data_list.append(entry.get("node_data", null))
	return node_data_list


func _apply_progress_to_node(
	playable_entry: Dictionary,
	playable_node_data: Array,
	node_index: int,
	node_selected_handler: Callable
) -> void:
	var scene_node: Node2D = playable_entry.get("scene_node", null) as Node2D
	var node_data = playable_entry.get("node_data", null)
	if scene_node == null or node_data == null:
		return

	var node_completed: bool = _is_node_completed(node_data)
	var node_unlocked: bool = _is_node_unlocked_by_order(
		playable_node_data,
		node_index,
		node_completed
	)

	scene_node.position = node_data.node_position
	scene_node.apply_node_state(node_data, node_unlocked, node_completed)
	if not scene_node.is_connected("node_selected", node_selected_handler):
		scene_node.connect("node_selected", node_selected_handler)


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
	var node_data = _read_node_data_from_selection(selected_target)
	if node_data != null:
		_open_selected_node(node_data)
		return

	var scene_path := str(selected_target).strip_edges()
	if scene_path.is_empty():
		push_warning("MapScene: Se intento abrir un destino vacio desde el mapa.")
		return

	get_tree().change_scene_to_file(scene_path)


func _read_node_data_from_selection(selected_target: Variant):
	if selected_target is Dictionary:
		return MapNodeDataScript.from_dictionary(selected_target as Dictionary)
	if selected_target is Object and selected_target.has_method("to_dictionary"):
		return selected_target
	return null


func _open_selected_node(node_data) -> void:
	var track_key: String = _get_valid_track_key(node_data)

	if node_data.is_question():
		_open_question_node(track_key, node_data)
		return

	_open_chapter_node(track_key, node_data)


func _open_question_node(track_key: String, node_data) -> void:
	var question_session_state: Dictionary = _build_question_session(track_key, node_data)
	Global.set_active_question_session(question_session_state)
	GameSceneRouter.go_to_questions(get_tree())


func _build_question_session(track_key: String, node_data) -> Dictionary:
	return {
		"track_key": track_key,
		"nivel_id": node_data.get_question_session_level_id(),
		"question_key": node_data.question_key,
		"question_resource_path": node_data.question_resource_path,
		"return_scene_path": GameSceneRouter.MAP_SCENE_PATH
	}


func _open_chapter_node(track_key: String, node_data) -> void:
	GameSceneRouter.go_to_track_level(
		get_tree(),
		track_key,
		node_data.level_number
	)


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
func _is_node_unlocked_by_order(
	playable_node_data: Array,
	index: int,
	completed: bool
) -> bool:
	if completed or index <= 0:
		return true
	return _is_node_completed(playable_node_data[index - 1])


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
