extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const MapNodeDataScript := preload("res://mapas/MapNodeData.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")
const PlayableNodeRouterScript := preload("res://mapas/PlayableNodeRouter.gd")
const MAP_COMPLETION_SCENE := preload("res://mapas/completo/CapituloCompletado.tscn")
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const MAP_VIEW_SYSTEM_KEY := "map_view"
const MAP_VIEW_SCROLL_VERTICAL_KEY := "scroll_vertical"

var escala_original := Vector2.ONE


@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	GameSceneRouter.request_scene_preload(
		GameTrackCatalog.obtener_ruta_escena_nivel(DEFAULT_TRACK_KEY)
	)
	_conectar_senal_volver()
	_limpiar_sesion_transitoria_de_pregunta()
	_renderizar_mapa_runtime()
	_restaurar_scroll_guardado_del_mapa()
	_mostrar_completado_del_mapa_si_corresponde()


func _limpiar_sesion_transitoria_de_pregunta() -> void:
	Global.limpiar_activo_pregunta_sesion()


func _conectar_senal_volver() -> void:
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _al_pedir_volver)


# Render del mapa -------------------------------------------------------------
func _renderizar_mapa_runtime() -> void:
	var runtime_map_nodes: Array[Node2D] = _obtener_nodos_jugables_runtime()
	if runtime_map_nodes.is_empty():
		push_warning("MapScene: MapBoard no expone nodos configurados en escena.")
		return

	var node_selected_handler := Callable(self, "_al_seleccionar_nodo")
	var previous_node_completed: bool = true

	for map_node in runtime_map_nodes:
		previous_node_completed = _configurar_nodo_runtime(
			map_node,
			previous_node_completed,
			node_selected_handler
		)


func _configurar_nodo_runtime(
	map_node: Node2D,
	previous_node_completed: bool,
	node_selected_handler: Callable
) -> bool:
	var runtime_node_data: RefCounted = MapNodeDataScript.duplicate_from_map_node(map_node)
	var node_completed: bool = _nodo_esta_completado(runtime_node_data)
	var node_unlocked: bool = previous_node_completed or node_completed

	map_node.position = runtime_node_data.node_position
	map_node.apply_node_state(runtime_node_data, node_unlocked, node_completed)
	if not map_node.is_connected("node_selected", node_selected_handler):
		map_node.connect("node_selected", node_selected_handler)

	return node_completed


func _mostrar_completado_del_mapa_si_corresponde() -> void:
	var runtime_map_nodes: Array[Node2D] = _obtener_nodos_jugables_runtime()
	if runtime_map_nodes.is_empty():
		return

	if not _estan_todos_los_nodos_completados(runtime_map_nodes):
		return

	var completed_track_key: String = _resolver_clave_de_pista_del_mapa(runtime_map_nodes)
	if completed_track_key.is_empty():
		return

	var completion_popup: Node = MAP_COMPLETION_SCENE.instantiate()
	if completion_popup == null:
		return
	if completion_popup.has_method("configure_for_track"):
		completion_popup.call("configure_for_track", completed_track_key)
	add_child(completion_popup)


func _estan_todos_los_nodos_completados(runtime_map_nodes: Array[Node2D]) -> bool:
	for map_node in runtime_map_nodes:
		var runtime_node_data: RefCounted = MapNodeDataScript.from_map_node(map_node)
		if not _nodo_esta_completado(runtime_node_data):
			return false
	return true


func _resolver_clave_de_pista_del_mapa(runtime_map_nodes: Array[Node2D]) -> String:
	for map_node in runtime_map_nodes:
		var runtime_node_data: RefCounted = MapNodeDataScript.from_map_node(map_node)
		var track_key: String = _obtener_clave_pista_valida(runtime_node_data)
		if not track_key.is_empty():
			return track_key
	return DEFAULT_TRACK_KEY


func obtener_datos_de_nodos_jugables() -> Array:
	var playable_node_data: Array = []
	for map_node in _obtener_nodos_jugables_runtime():
		playable_node_data.append(MapNodeDataScript.duplicate_from_map_node(map_node))
	return playable_node_data


func obtener_definiciones_de_nodos_jugables() -> Array[Dictionary]:
	var node_definitions: Array[Dictionary] = []
	for node_data in obtener_datos_de_nodos_jugables():
		node_definitions.append(node_data.to_dictionary())
	return node_definitions


func obtener_contenedor_de_nodos() -> Node2D:
	if map_board != null and map_board.has_method("get_nodes_container"):
		return map_board.call("get_nodes_container") as Node2D
	return null


func _obtener_nodos_jugables_runtime() -> Array[Node2D]:
	var runtime_map_nodes: Array[Node2D] = []
	for map_node in _obtener_nodos_del_tablero():
		var runtime_node_data: RefCounted = MapNodeDataScript.from_map_node(map_node)
		if not _nodo_se_puede_abrir_desde_mapa(runtime_node_data):
			_ocultar_nodo_sin_destino(map_node)
			continue

		map_node.visible = true
		runtime_map_nodes.append(map_node)

	return runtime_map_nodes


func _ocultar_nodo_sin_destino(map_node: Node2D) -> void:
	push_warning("MapScene: Hay un nodo del mapa sin destino configurado.")
	map_node.visible = false


func _obtener_nodos_del_tablero() -> Array[Node2D]:
	var board_nodes: Array[Node2D] = []
	if map_board == null:
		return board_nodes

	if not map_board.has_method("get_runtime_map_nodes"):
		return board_nodes

	var raw_nodes: Array = map_board.call("get_runtime_map_nodes")

	for raw_node in raw_nodes:
		var map_node: Node2D = raw_node as Node2D
		if map_node != null:
			board_nodes.append(map_node)
	return board_nodes


# Navegacion -----------------------------------------------------------------
func _al_seleccionar_nodo(selected_target: Variant) -> void:
	_guardar_scroll_actual_del_mapa()
	var selected_node_data: RefCounted = MapNodeDataScript.from_selection_payload(selected_target)
	if selected_node_data == null:
		_abrir_ruta_directa(selected_target)
		return

	_abrir_nodo_seleccionado(selected_node_data)


func _abrir_ruta_directa(selected_target: Variant) -> void:
	var scene_path := str(selected_target).strip_edges()
	if scene_path.is_empty():
		push_warning("MapScene: Se intento abrir un destino vacio desde el mapa.")
		return

	get_tree().change_scene_to_file(scene_path)


func _abrir_nodo_seleccionado(node_data: RefCounted) -> void:
	var track_key: String = _obtener_clave_pista_valida(node_data)
	if node_data.is_question():
		_abrir_nodo_jugable(track_key, node_data)
		return

	_abrir_nodo_capitulo(track_key, node_data)



func _abrir_nodo_jugable(track_key: String, node_data: RefCounted) -> void:
	var session_context: Dictionary = _crear_contexto_nodo_jugable(track_key, node_data)
	var load_result: Dictionary = _cargar_contenido_nodo(session_context)
	if not bool(load_result.get("ok", false)):
		_mostrar_error_nodo(str(load_result.get("error", "")).strip_edges())
		_abrir_escena_jugable(GameSceneRouter.QUESTIONS_SCENE_PATH, session_context)
		return

	var datos_nodo: Dictionary = load_result.get("data", {})
	var route_result: Dictionary = _obtener_escena_jugable(datos_nodo)
	if not bool(route_result.get("ok", false)):
		_mostrar_error_nodo(
			str(route_result.get("error", "No se pudo resolver la escena del nodo jugable.")),
			true
		)
		_abrir_escena_jugable(GameSceneRouter.QUESTIONS_SCENE_PATH, session_context)
		return

	var scene_path: String = str(
		route_result.get("scene_path", GameSceneRouter.QUESTIONS_SCENE_PATH)
	).strip_edges()
	_abrir_escena_jugable(scene_path, _crear_contexto_enrutado(session_context, datos_nodo))


func _abrir_nodo_capitulo(track_key: String, node_data: RefCounted) -> void:
	GameSceneRouter.go_to_track_level(
		get_tree(),
		track_key,
		node_data.level_number
	)

func _crear_contexto_nodo_jugable(track_key: String, node_data: RefCounted) -> Dictionary:
	return node_data.build_question_session(track_key, GameSceneRouter.MAP_SCENE_PATH)


func _cargar_contenido_nodo(session_context: Dictionary) -> Dictionary:
	var node_json_path: String = str(session_context.get("question_json_path", "")).strip_edges()
	if node_json_path.is_empty():
		return {
			"ok": false,
			"data": {},
			"error": ""
		}
	return NodeContentLoaderScript.load_node_content(node_json_path)


func _obtener_escena_jugable(datos_nodo: Dictionary) -> Dictionary:
	return PlayableNodeRouterScript.obtener_escena_jugable(
		str(datos_nodo.get("mode", "")).strip_edges()
	)


func _abrir_escena_jugable(scene_path: String, session_context: Dictionary) -> void:
	Global.establecer_activo_pregunta_sesion(session_context)
	if scene_path == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(get_tree())
		return
	get_tree().change_scene_to_file(scene_path)


func _crear_contexto_enrutado(
	session_context: Dictionary,
	datos_nodo: Dictionary
) -> Dictionary:
	var routed_session: Dictionary = session_context.duplicate(true)
	routed_session["node_mode"] = str(datos_nodo.get("mode", "")).strip_edges()
	routed_session["node_content"] = datos_nodo
	return routed_session


func _mostrar_error_nodo(message: String, es_bloqueante: bool = false) -> void:
	if message.is_empty():
		return
	if es_bloqueante:
		push_error("MapScene: %s" % message)
		return
	push_warning(
		"MapScene: no se pudo cargar el nodo jugable desde JSON. Se usa el flujo fallback. %s"
		% message
	)


func _guardar_scroll_actual_del_mapa() -> void:
	var map_view_state: Dictionary = Global.obtener_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY)
	map_view_state[MAP_VIEW_SCROLL_VERTICAL_KEY] = _obtener_scroll_vertical_actual()
	Global.establecer_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY, map_view_state)


func _restaurar_scroll_guardado_del_mapa() -> void:
	var map_view_state: Dictionary = Global.obtener_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY)
	var saved_scroll_vertical: int = int(map_view_state.get(MAP_VIEW_SCROLL_VERTICAL_KEY, 0))
	_establecer_scroll_vertical_actual(saved_scroll_vertical)


func _obtener_scroll_vertical_actual() -> int:
	if map_board != null and map_board.has_method("get_scroll_vertical_value"):
		return int(map_board.call("get_scroll_vertical_value"))
	return 0


func _establecer_scroll_vertical_actual(scroll_value: int) -> void:
	if map_board != null and map_board.has_method("set_scroll_vertical_value"):
		map_board.call("set_scroll_vertical_value", scroll_value)


func _nodo_se_puede_abrir_desde_mapa(node_data: RefCounted) -> bool:
	if node_data == null:
		return false
	if not node_data.has_runtime_destination():
		return false
	if node_data.is_question():
		return true
	return node_data.has_chapter_destination() and GameTrackCatalog.tiene_pista(
		_obtener_clave_pista_valida(node_data)
	)


# Progreso -------------------------------------------------------------------
func _nodo_esta_completado(node_data: RefCounted) -> bool:
	var track_key: String = _obtener_clave_pista_valida(node_data)
	if node_data.is_question():
		return Global.es_pregunta_completado(track_key, node_data.question_key)
	return Global.es_nivel_completado(track_key, node_data.level_number)


func _obtener_clave_pista_valida(node_data: RefCounted) -> String:
	var raw_track_key: String = node_data.get_track_key_or_default(DEFAULT_TRACK_KEY)
	if GameTrackCatalog.tiene_pista(raw_track_key):
		return raw_track_key
	return DEFAULT_TRACK_KEY


# Salida ---------------------------------------------------------------------
func _al_pedir_volver() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
