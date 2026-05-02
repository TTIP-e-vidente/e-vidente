extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const MapJsonLoaderScript := preload("res://mapas/core/MapJsonLoader.gd")
const MapProgressScript := preload("res://mapas/core/MapProgress.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const PlayableNodeRouterScript := preload("res://mapas/core/PlayableNodeRouter.gd")
const MAP_COMPLETION_SCENE := preload("res://mapas/completo/CapituloCompletado.tscn")

const MAP_JSON_PATH := "res://contenido/mapas/celiaquia_mapa.json"
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const MAP_VIEW_SYSTEM_KEY := "map_view"
const MAP_VIEW_SCROLL_VERTICAL_KEY := "scroll_vertical"

var map_id: String = ""
var map_title: String = ""
var track_key_mapa: String = DEFAULT_TRACK_KEY
var nodos_mapa: Array[MapNodeData] = []

@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


func _ready() -> void:
	_connect_signals()
	cargar_mapa()
	GameSceneRouter.request_scene_preload(
		GameTrackCatalog.obtener_ruta_escena_nivel(track_key_mapa)
	)

	Global.limpiar_sesion_nodo_jugable_activo()
	mostrar_nodos()
	_restaurar_scroll_guardado_del_mapa()

	var nodo_actual: String = Global.consumir_nodo_a_continuar()
	if not nodo_actual.is_empty():
		continuar_desde_nodo(nodo_actual)
		return

	_mostrar_completado_del_mapa_si_corresponde()


func _connect_signals() -> void:
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _al_pedir_volver)
	if map_board != null and map_board.has_signal("node_selected"):
		map_board.connect("node_selected", al_seleccionar_nodo)


func cargar_mapa() -> void:
	var result: Dictionary = MapJsonLoaderScript.load_map(MAP_JSON_PATH)
	if not bool(result.get("ok", false)):
		map_id = ""
		map_title = ""
		nodos_mapa = []
		track_key_mapa = DEFAULT_TRACK_KEY
		_mostrar_error(str(result.get("error", "No se pudo cargar el mapa.")))
		return

	var map_data: Dictionary = result.get("data", {})
	map_id = str(map_data.get("id", "")).strip_edges()
	map_title = str(map_data.get("title", "")).strip_edges()
	track_key_mapa = _valid_track_key(str(map_data.get("track_key", DEFAULT_TRACK_KEY)))
	nodos_mapa = []

	var loaded_nodes: Variant = map_data.get("nodes", [])
	if loaded_nodes is Array:
		for raw_node in (loaded_nodes as Array):
			var node_data: MapNodeData = raw_node as MapNodeData
			if node_data != null:
				nodos_mapa.append(node_data)


func mostrar_nodos() -> void:
	if map_board == null or not map_board.has_method("configurar_nodos"):
		return

	var unlocked_by_index: Array[bool] = []
	var completed_by_index: Array[bool] = []
	for index in range(nodos_mapa.size()):
		var node_data: MapNodeData = nodos_mapa[index]
		var completed: bool = Global.es_nodo_jugable_completado(
			track_key_mapa,
			node_data.node_key
		)
		completed_by_index.append(completed)
		unlocked_by_index.append(
			MapProgressScript.nodo_esta_desbloqueado(
				nodos_mapa,
				index,
				track_key_mapa,
				completed
			)
		)

	map_board.call("configurar_nodos", nodos_mapa, unlocked_by_index, completed_by_index)


func al_seleccionar_nodo(node_data: MapNodeData) -> void:
	if node_data == null or not node_data.is_valid():
		_mostrar_error("No se pudo leer el nodo seleccionado.")
		return

	_guardar_scroll_actual_del_mapa()
	abrir_nodo_del_mapa(node_data)


func abrir_nodo_del_mapa(node_data: MapNodeData) -> void:
	var result: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(node_data.json_path)
	if not bool(result.get("ok", false)):
		_mostrar_error(str(result.get("error", "No se pudo cargar el nodo.")))
		return

	var level_data: Dictionary = result.get("data", {})
	var mode: String = str(level_data.get("mode", "")).strip_edges()
	var scene_path: String = PlayableNodeRouterScript.obtener_escena_jugable(mode)
	if scene_path.is_empty():
		_mostrar_error("No existe escena para el modo: %s" % mode)
		return

	abrir_escena_jugable(scene_path, _crear_contexto_sesion(node_data, mode))


func abrir_escena_jugable(scene_path: String, session_context: Dictionary) -> void:
	Global.establecer_sesion_nodo_jugable_activo(session_context)
	if scene_path == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(get_tree())
		return
	get_tree().change_scene_to_file(scene_path)


func continuar_desde_nodo(node_key: String) -> void:
	var next_node: MapNodeData = obtener_siguiente_nodo(node_key)
	if next_node == null:
		volver_al_mapa()
		return
	abrir_nodo_del_mapa(next_node)


func obtener_siguiente_nodo(node_key: String) -> MapNodeData:
	return MapProgressScript.obtener_siguiente_nodo(nodos_mapa, node_key) as MapNodeData


func obtener_nodo_mapa(node_key: String) -> MapNodeData:
	var clean_node_key: String = node_key.strip_edges()
	for node_data in nodos_mapa:
		if node_data.node_key == clean_node_key:
			return node_data
	return null


func volver_al_mapa() -> void:
	_mostrar_completado_del_mapa_si_corresponde()


func _crear_contexto_sesion(node_data: MapNodeData, mode: String) -> Dictionary:
	return {
		"node_key": node_data.node_key,
		"node_title": node_data.title,
		"json_path": node_data.json_path,
		"track_key": track_key_mapa,
		"nivel_id": node_data.index + 1,
		"node_mode": mode,
		"return_to": GameSceneRouter.MAP_SCENE_PATH,
	}


func _mostrar_completado_del_mapa_si_corresponde() -> void:
	if not MapProgressScript.mapa_esta_completado(nodos_mapa, track_key_mapa):
		return

	var popup_completado: Node = MAP_COMPLETION_SCENE.instantiate()
	if popup_completado == null:
		return
	if popup_completado.has_method("configure_for_track"):
		popup_completado.call("configure_for_track", track_key_mapa)
	add_child(popup_completado)


func _valid_track_key(raw_track_key: String) -> String:
	var clean_track_key: String = raw_track_key.strip_edges()
	if clean_track_key.is_empty() or not GameTrackCatalog.tiene_pista(clean_track_key):
		return DEFAULT_TRACK_KEY
	return clean_track_key


func _mostrar_error(mensaje: String) -> void:
	push_error("MapScene: %s" % mensaje)


func _guardar_scroll_actual_del_mapa() -> void:
	var map_view_state: Dictionary = Global.obtener_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY)
	var scroll_vertical_actual: int = 0
	if map_board != null and map_board.has_method("obtener_scroll_vertical"):
		scroll_vertical_actual = int(map_board.call("obtener_scroll_vertical"))
	map_view_state[MAP_VIEW_SCROLL_VERTICAL_KEY] = scroll_vertical_actual
	Global.establecer_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY, map_view_state)


func _restaurar_scroll_guardado_del_mapa() -> void:
	var map_view_state: Dictionary = Global.obtener_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY)
	var scroll_vertical_guardado: int = int(map_view_state.get(MAP_VIEW_SCROLL_VERTICAL_KEY, 0))
	if map_board != null and map_board.has_method("establecer_scroll_vertical"):
		map_board.call("establecer_scroll_vertical", scroll_vertical_guardado)


func _al_pedir_volver() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
