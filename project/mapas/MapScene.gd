extends Node2D
## Orquesta el mapa authored en escena: prepara nodos, calcula progreso y abre destinos.

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const MapNodeDataScript := preload("res://mapas/MapNodeData.gd")
const MAP_COMPLETION_SCENE := preload("res://mapas/completo/CapituloCompletado.tscn")
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const MAP_VIEW_SYSTEM_KEY := "map_view"
const MAP_VIEW_SCROLL_VERTICAL_KEY := "scroll_vertical"


@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	_connect_back_signal()
	_clear_transient_question_session()
	_render_runtime_map()
	_restore_saved_map_scroll()
	_show_map_completion_if_needed()


func _clear_transient_question_session() -> void:
	Global.clear_active_question_session()


func _connect_back_signal() -> void:
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _on_back_requested)


# Render del mapa -------------------------------------------------------------
func _refresh_map_nodes() -> void:
	_render_runtime_map()


func _render_runtime_map() -> void:
	var runtime_map_nodes: Array[Node2D] = _get_runtime_playable_map_nodes()
	if runtime_map_nodes.is_empty():
		push_warning("MapScene: MapBoard no expone nodos configurados en escena.")
		return

	var node_selected_handler := Callable(self, "_on_node_selected")
	var previous_node_completed: bool = true

	for map_node in runtime_map_nodes:
		previous_node_completed = _configure_runtime_map_node(
			map_node,
			previous_node_completed,
			node_selected_handler
		)


func _configure_runtime_map_node(
	map_node: Node2D,
	previous_node_completed: bool,
	node_selected_handler: Callable
) -> bool:
	var runtime_node_data: RefCounted = _duplicate_runtime_node_data_from_node(map_node)
	var node_completed: bool = _is_node_completed(runtime_node_data)
	var node_unlocked: bool = previous_node_completed or node_completed

	map_node.position = runtime_node_data.node_position
	map_node.apply_node_state(runtime_node_data, node_unlocked, node_completed)
	if not map_node.is_connected("node_selected", node_selected_handler):
		map_node.connect("node_selected", node_selected_handler)

	return node_completed


func _show_map_completion_if_needed() -> void:
	var runtime_map_nodes: Array[Node2D] = _get_runtime_playable_map_nodes()
	if runtime_map_nodes.is_empty():
		return

	if not _are_all_runtime_map_nodes_completed(runtime_map_nodes):
		return

	var completed_track_key: String = _resolve_map_track_key(runtime_map_nodes)
	if completed_track_key.is_empty():
		return

	var completion_popup: Node = MAP_COMPLETION_SCENE.instantiate()
	if completion_popup == null:
		return
	if completion_popup.has_method("configure_for_track"):
		completion_popup.call("configure_for_track", completed_track_key)
	add_child(completion_popup)


func _are_all_runtime_map_nodes_completed(runtime_map_nodes: Array[Node2D]) -> bool:
	for map_node in runtime_map_nodes:
		var runtime_node_data: RefCounted = _build_runtime_node_data_from_node(map_node)
		if not _is_node_completed(runtime_node_data):
			return false
	return true


func _resolve_map_track_key(runtime_map_nodes: Array[Node2D]) -> String:
	for map_node in runtime_map_nodes:
		var runtime_node_data: RefCounted = _build_runtime_node_data_from_node(map_node)
		var track_key: String = _get_valid_track_key(runtime_node_data)
		if not track_key.is_empty():
			return track_key
	return DEFAULT_TRACK_KEY


func get_playable_node_data() -> Array:
	var playable_node_data: Array = []
	for map_node in _get_runtime_playable_map_nodes():
		playable_node_data.append(_duplicate_runtime_node_data_from_node(map_node))
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


func _get_runtime_playable_map_nodes() -> Array[Node2D]:
	var runtime_map_nodes: Array[Node2D] = []
	for map_node in _get_board_nodes():
		var runtime_node_data: RefCounted = _build_runtime_node_data_from_node(map_node)
		if not _node_can_be_opened_from_map(runtime_node_data):
			_hide_unconfigured_map_node(map_node)
			continue

		map_node.visible = true
		runtime_map_nodes.append(map_node)

	return runtime_map_nodes


func _hide_unconfigured_map_node(map_node: Node2D) -> void:
	push_warning("MapScene: Hay un nodo del mapa sin destino configurado.")
	map_node.visible = false


func _build_runtime_node_data_from_node(map_node: Node2D) -> RefCounted:
	var runtime_node_data: RefCounted = null
	if map_node.has_method("build_runtime_node_data"):
		runtime_node_data = map_node.call("build_runtime_node_data")
	else:
		runtime_node_data = map_node.call("build_node_data")
	return runtime_node_data


func _duplicate_runtime_node_data_from_node(map_node: Node2D) -> RefCounted:
	var runtime_node_data: RefCounted = _build_runtime_node_data_from_node(map_node)
	return runtime_node_data.duplicate_data()


func _get_board_nodes() -> Array[Node2D]:
	var board_nodes: Array[Node2D] = []
	if map_board == null:
		return board_nodes

	var raw_nodes: Array = []
	if map_board.has_method("get_runtime_map_nodes"):
		raw_nodes = map_board.call("get_runtime_map_nodes")
	elif map_board.has_method("get_authored_level_nodes"):
		raw_nodes = map_board.call("get_authored_level_nodes")
	else:
		return board_nodes

	for raw_node in raw_nodes:
		var map_node: Node2D = raw_node as Node2D
		if map_node != null:
			board_nodes.append(map_node)
	return board_nodes


# Navegacion -----------------------------------------------------------------
func _on_node_selected(selected_target: Variant) -> void:
	_save_current_map_scroll()
	var selected_node_data: RefCounted = _build_node_data_from_selection(selected_target)
	if selected_node_data == null:
		_open_direct_scene_path(selected_target)
		return

	_open_map_node(selected_node_data)


func _open_direct_scene_path(selected_target: Variant) -> void:
	var scene_path := str(selected_target).strip_edges()
	if scene_path.is_empty():
		push_warning("MapScene: Se intento abrir un destino vacio desde el mapa.")
		return

	get_tree().change_scene_to_file(scene_path)


func _open_map_node(node_data: RefCounted) -> void:
	var track_key: String = _get_valid_track_key(node_data)
	if node_data.is_question():
		_open_question_node(track_key, node_data)
		return

	_open_chapter_node(track_key, node_data)



func _open_question_node(track_key: String, node_data: RefCounted) -> void:
	Global.set_active_question_session(_build_question_session(track_key, node_data))
	GameSceneRouter.go_to_questions(get_tree())


func _open_chapter_node(track_key: String, node_data: RefCounted) -> void:
	GameSceneRouter.go_to_track_level(
		get_tree(),
		track_key,
		node_data.level_number
	)


func _build_node_data_from_selection(selected_target: Variant) -> RefCounted:
	return MapNodeDataScript.from_selection_payload(selected_target)


func _build_question_session(track_key: String, node_data: RefCounted) -> Dictionary:
	return {
		"track_key": track_key,
		"nivel_id": node_data.get_question_session_level_id(),
		"question_key": node_data.question_key,
		"question_resource_path": node_data.question_resource_path,
		"return_scene_path": GameSceneRouter.MAP_SCENE_PATH
	}


func _save_current_map_scroll() -> void:
	var map_view_state: Dictionary = Global.get_progress_system_state(MAP_VIEW_SYSTEM_KEY)
	map_view_state[MAP_VIEW_SCROLL_VERTICAL_KEY] = _get_current_map_scroll_vertical()
	Global.set_progress_system_state(MAP_VIEW_SYSTEM_KEY, map_view_state)


func _restore_saved_map_scroll() -> void:
	var map_view_state: Dictionary = Global.get_progress_system_state(MAP_VIEW_SYSTEM_KEY)
	var saved_scroll_vertical: int = int(map_view_state.get(MAP_VIEW_SCROLL_VERTICAL_KEY, 0))
	_set_current_map_scroll_vertical(saved_scroll_vertical)


func _get_current_map_scroll_vertical() -> int:
	if map_board != null and map_board.has_method("get_scroll_vertical_value"):
		return int(map_board.call("get_scroll_vertical_value"))
	return 0


func _set_current_map_scroll_vertical(scroll_value: int) -> void:
	if map_board != null and map_board.has_method("set_scroll_vertical_value"):
		map_board.call("set_scroll_vertical_value", scroll_value)


func _node_can_be_opened_from_map(node_data: RefCounted) -> bool:
	if node_data == null:
		return false
	if not node_data.has_runtime_destination():
		return false
	if node_data.is_question():
		return true
	return node_data.has_chapter_destination() and GameTrackCatalog.has_track(
		_get_valid_track_key(node_data)
	)


# Progreso -------------------------------------------------------------------
func _is_node_completed(node_data: RefCounted) -> bool:
	var track_key: String = _get_valid_track_key(node_data)
	if node_data.is_question():
		return Global.is_question_completed(track_key, node_data.question_key)
	return Global.is_level_completed(track_key, node_data.level_number)


func _get_valid_track_key(node_data: RefCounted) -> String:
	var raw_track_key: String = node_data.get_track_key_or_default(DEFAULT_TRACK_KEY)
	if GameTrackCatalog.has_track(raw_track_key):
		return raw_track_key
	return DEFAULT_TRACK_KEY


# Salida ---------------------------------------------------------------------
func _on_back_requested() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
