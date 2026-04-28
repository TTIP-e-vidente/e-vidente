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


@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	GameSceneRouter.request_scene_preload(
		GameTrackCatalog.obtener_ruta_escena_nivel(DEFAULT_TRACK_KEY)
	)
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _al_pedir_volver)
	Global.limpiar_sesion_nodo_jugable_activo()
	_renderizar_mapa_runtime()
	_restaurar_scroll_guardado_del_mapa()
	_mostrar_completado_del_mapa_si_corresponde()


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
	var runtime_node_data: RefCounted = MapNodeDataScript.duplicar_desde_nodo_mapa(map_node)
	var node_completed: bool = _nodo_esta_completado(runtime_node_data)
	var node_unlocked: bool = previous_node_completed or node_completed

	map_node.position = runtime_node_data.node_position
	map_node.aplicar_estado_nodo(runtime_node_data, node_unlocked, node_completed)
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
		var runtime_node_data: RefCounted = MapNodeDataScript.desde_nodo_mapa(map_node)
		if not _nodo_esta_completado(runtime_node_data):
			return false
	return true


func _resolver_clave_de_pista_del_mapa(runtime_map_nodes: Array[Node2D]) -> String:
	for map_node in runtime_map_nodes:
		var runtime_node_data: RefCounted = MapNodeDataScript.desde_nodo_mapa(map_node)
		var track_key: String = _obtener_clave_pista_valida(runtime_node_data)
		if not track_key.is_empty():
			return track_key
	return DEFAULT_TRACK_KEY


func obtener_contenedor_de_nodos() -> Node2D:
	if map_board != null and map_board.has_method("obtener_contenedor_nodos"):
		return map_board.call("obtener_contenedor_nodos") as Node2D
	return null


func _obtener_nodos_jugables_runtime() -> Array[Node2D]:
	var runtime_map_nodes: Array[Node2D] = []
	for map_node in _obtener_nodos_del_tablero():
		var runtime_node_data: RefCounted = MapNodeDataScript.desde_nodo_mapa(map_node)
		if not _nodo_se_puede_abrir_desde_mapa(runtime_node_data):
			push_warning("MapScene: Hay un nodo del mapa sin destino configurado.")
			map_node.visible = false
			continue

		map_node.visible = true
		runtime_map_nodes.append(map_node)

	return runtime_map_nodes


func _obtener_nodos_del_tablero() -> Array[Node2D]:
	var board_nodes: Array[Node2D] = []
	if map_board == null:
		return board_nodes

	if not map_board.has_method("obtener_nodos_runtime_mapa"):
		return board_nodes

	var raw_nodes: Array = map_board.call("obtener_nodos_runtime_mapa")

	for raw_node in raw_nodes:
		var map_node: Node2D = raw_node as Node2D
		if map_node != null:
			board_nodes.append(map_node)
	return board_nodes


# Navegacion -----------------------------------------------------------------
func _al_seleccionar_nodo(destino_seleccionado: Variant) -> void:
	_guardar_scroll_actual_del_mapa()
	var datos_mapa_nodo: RefCounted = MapNodeDataScript.desde_seleccion(destino_seleccionado)
	if datos_mapa_nodo == null:
		var ruta_escena: String = str(destino_seleccionado).strip_edges()
		if ruta_escena.is_empty():
			push_warning("MapScene: Se intento abrir un destino vacio desde el mapa.")
			return

		get_tree().change_scene_to_file(ruta_escena)
		return

	_abrir_nodo_seleccionado(datos_mapa_nodo)


func _abrir_nodo_seleccionado(datos_nodo_mapa: RefCounted) -> void:
	var clave_pista: String = _obtener_clave_pista_valida(datos_nodo_mapa)
	if datos_nodo_mapa.es_nodo_jugable():
		_abrir_nodo_jugable(clave_pista, datos_nodo_mapa)
		return

	GameSceneRouter.go_to_track_level(
		get_tree(),
		clave_pista,
		datos_nodo_mapa.level_number
	)


func _abrir_nodo_jugable(clave_pista: String, datos_nodo_mapa: RefCounted) -> void:
	var contexto_sesion: Dictionary = datos_nodo_mapa.crear_contexto_sesion(
		clave_pista,
		GameSceneRouter.MAP_SCENE_PATH
	)
	var resultado_contenido: Dictionary = _cargar_contenido_nodo(contexto_sesion)
	if not bool(resultado_contenido.get("ok", false)):
		_abrir_fallback_legacy_del_nodo(
			contexto_sesion,
			str(resultado_contenido.get("error", "")).strip_edges(),
			bool(resultado_contenido.get("es_bloqueante", false))
		)
		return

	var datos_nodo: Dictionary = resultado_contenido.get("data", {})
	var resultado_escena: Dictionary = _obtener_escena_jugable(datos_nodo)
	if not bool(resultado_escena.get("ok", false)):
		_abrir_fallback_legacy_del_nodo(
			contexto_sesion,
			str(resultado_escena.get("error", "No se pudo resolver la escena del nodo jugable.")).strip_edges(),
			bool(resultado_escena.get("es_bloqueante", false))
		)
		return

	var ruta_escena: String = str(
		resultado_escena.get("ruta_escena", GameSceneRouter.QUESTIONS_SCENE_PATH)
	).strip_edges()
	contexto_sesion["node_mode"] = str(datos_nodo.get("mode", "")).strip_edges()
	contexto_sesion["node_data"] = datos_nodo
	_abrir_escena_jugable(ruta_escena, contexto_sesion)


func _cargar_contenido_nodo(contexto_sesion: Dictionary) -> Dictionary:
	var ruta_json_nodo: String = str(contexto_sesion.get("node_json_path", "")).strip_edges()
	if ruta_json_nodo.is_empty():
		return {
			"ok": false,
			"error": "El nodo no tiene un JSON configurado. Se intenta el fallback legacy.",
			"es_bloqueante": false
		}

	return NodeContentLoaderScript.cargar_contenido_nodo(ruta_json_nodo)


func _obtener_escena_jugable(datos_nodo: Dictionary) -> Dictionary:
	var resultado_ruta: Dictionary = PlayableNodeRouterScript.obtener_escena_jugable(
		str(datos_nodo.get("mode", "")).strip_edges()
	)
	if bool(resultado_ruta.get("ok", false)):
		return resultado_ruta

	var error: String = str(
		resultado_ruta.get("error", "No se pudo resolver la escena del nodo jugable.")
	).strip_edges()
	return {
		"ok": false,
		"ruta_escena": "",
		"error": error,
		"es_bloqueante": true
	}


func _abrir_escena_jugable(ruta_escena: String, contexto_sesion: Dictionary) -> void:
	Global.establecer_sesion_nodo_jugable_activo(contexto_sesion)
	if ruta_escena == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(get_tree())
		return
	get_tree().change_scene_to_file(ruta_escena)


func _abrir_fallback_legacy_del_nodo(
	contexto_sesion: Dictionary,
	mensaje_error: String,
	es_bloqueante: bool = false
) -> void:
	if not mensaje_error.is_empty():
		if es_bloqueante:
			push_error("MapScene: %s" % mensaje_error)
		else:
			push_warning(
				"MapScene: no se pudo cargar el nodo jugable desde JSON. Se usa el flujo fallback. %s"
				% mensaje_error
			)
	_abrir_escena_jugable(GameSceneRouter.QUESTIONS_SCENE_PATH, contexto_sesion)


func _guardar_scroll_actual_del_mapa() -> void:
	var map_view_state: Dictionary = Global.obtener_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY)
	var scroll_vertical_actual: int = 0
	if map_board != null and map_board.has_method("obtener_scroll_vertical"):
		scroll_vertical_actual = int(map_board.call("obtener_scroll_vertical"))
	map_view_state[MAP_VIEW_SCROLL_VERTICAL_KEY] = scroll_vertical_actual
	Global.establecer_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY, map_view_state)


func _restaurar_scroll_guardado_del_mapa() -> void:
	var map_view_state: Dictionary = Global.obtener_progreso_sistema_estado(MAP_VIEW_SYSTEM_KEY)
	var saved_scroll_vertical: int = int(map_view_state.get(MAP_VIEW_SCROLL_VERTICAL_KEY, 0))
	if map_board != null and map_board.has_method("establecer_scroll_vertical"):
		map_board.call("establecer_scroll_vertical", saved_scroll_vertical)


func _nodo_se_puede_abrir_desde_mapa(node_data: RefCounted) -> bool:
	if node_data == null:
		return false
	if not node_data.tiene_destino_runtime():
		return false
	if node_data.es_nodo_jugable():
		return true
	return node_data.tiene_destino_capitulo() and GameTrackCatalog.tiene_pista(
		_obtener_clave_pista_valida(node_data)
	)


# Progreso -------------------------------------------------------------------
func _nodo_esta_completado(node_data: RefCounted) -> bool:
	var track_key: String = _obtener_clave_pista_valida(node_data)
	if node_data.es_nodo_jugable():
		return Global.es_nodo_jugable_completado(track_key, node_data.resolver_clave_nodo())
	return Global.es_nivel_completado(track_key, node_data.level_number)


func _obtener_clave_pista_valida(node_data: RefCounted) -> String:
	var raw_track_key: String = node_data.obtener_clave_pista_o_default(DEFAULT_TRACK_KEY)
	if GameTrackCatalog.tiene_pista(raw_track_key):
		return raw_track_key
	return DEFAULT_TRACK_KEY


# Salida ---------------------------------------------------------------------
func _al_pedir_volver() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
