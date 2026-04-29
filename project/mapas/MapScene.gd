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

	var handler_nodo_seleccionado := Callable(self, "_al_seleccionar_nodo")
	var nodo_previo_completado: bool = true

	for nodo_visual in runtime_map_nodes:
		nodo_previo_completado = _configurar_nodo_runtime(
			nodo_visual,
			nodo_previo_completado,
			handler_nodo_seleccionado
		)


func _configurar_nodo_runtime(
	nodo_visual: Node2D,
	nodo_previo_completado: bool,
	handler_nodo_seleccionado: Callable
) -> bool:
	var datos_mapa_nodo: RefCounted = MapNodeDataScript.duplicar_desde_nodo_mapa(nodo_visual)
	var esta_completado: bool = _nodo_esta_completado(datos_mapa_nodo)
	var esta_desbloqueado: bool = nodo_previo_completado or esta_completado

	nodo_visual.position = datos_mapa_nodo.node_position
	nodo_visual.aplicar_estado_nodo(datos_mapa_nodo, esta_desbloqueado, esta_completado)
	if not nodo_visual.is_connected("node_selected", handler_nodo_seleccionado):
		nodo_visual.connect("node_selected", handler_nodo_seleccionado)

	return esta_completado


func _mostrar_completado_del_mapa_si_corresponde() -> void:
	var runtime_map_nodes: Array[Node2D] = _obtener_nodos_jugables_runtime()
	if runtime_map_nodes.is_empty():
		return

	if not _estan_todos_los_nodos_completados(runtime_map_nodes):
		return

	var clave_pista_completada: String = _resolver_clave_de_pista_del_mapa(runtime_map_nodes)
	if clave_pista_completada.is_empty():
		return

	var popup_completado: Node = MAP_COMPLETION_SCENE.instantiate()
	if popup_completado == null:
		return
	if popup_completado.has_method("configure_for_track"):
		popup_completado.call("configure_for_track", clave_pista_completada)
	add_child(popup_completado)


func _estan_todos_los_nodos_completados(runtime_map_nodes: Array[Node2D]) -> bool:
	for nodo_visual in runtime_map_nodes:
		var datos_mapa_nodo: RefCounted = MapNodeDataScript.desde_nodo_mapa(nodo_visual)
		if not _nodo_esta_completado(datos_mapa_nodo):
			return false
	return true


func _resolver_clave_de_pista_del_mapa(runtime_map_nodes: Array[Node2D]) -> String:
	for nodo_visual in runtime_map_nodes:
		var datos_mapa_nodo: RefCounted = MapNodeDataScript.desde_nodo_mapa(nodo_visual)
		var track_key: String = _obtener_clave_pista_valida(datos_mapa_nodo)
		if not track_key.is_empty():
			return track_key
	return DEFAULT_TRACK_KEY


func obtener_contenedor_de_nodos() -> Node2D:
	if map_board != null and map_board.has_method("obtener_contenedor_nodos"):
		return map_board.call("obtener_contenedor_nodos") as Node2D
	return null


func _obtener_nodos_jugables_runtime() -> Array[Node2D]:
	var runtime_map_nodes: Array[Node2D] = []
	for nodo_visual in _obtener_nodos_del_tablero():
		var datos_mapa_nodo: RefCounted = MapNodeDataScript.desde_nodo_mapa(nodo_visual)
		if not _nodo_se_puede_abrir_desde_mapa(datos_mapa_nodo):
			push_warning("MapScene: Hay un nodo del mapa sin destino configurado.")
			nodo_visual.visible = false
			continue

		nodo_visual.visible = true
		runtime_map_nodes.append(nodo_visual)

	return runtime_map_nodes


func _obtener_nodos_del_tablero() -> Array[Node2D]:
	var nodos_tablero: Array[Node2D] = []
	if map_board == null:
		return nodos_tablero

	if not map_board.has_method("obtener_nodos_runtime_mapa"):
		return nodos_tablero

	var nodos_crudos: Array = map_board.call("obtener_nodos_runtime_mapa")

	for nodo_crudo in nodos_crudos:
		var nodo_visual: Node2D = nodo_crudo as Node2D
		if nodo_visual != null:
			nodos_tablero.append(nodo_visual)
	return nodos_tablero


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


func _abrir_nodo_seleccionado(datos_mapa_nodo: RefCounted) -> void:
	var clave_pista: String = _obtener_clave_pista_valida(datos_mapa_nodo)
	if datos_mapa_nodo.es_nodo_jugable():
		_abrir_nodo_jugable(clave_pista, datos_mapa_nodo)
		return

	GameSceneRouter.go_to_track_level(
		get_tree(),
		clave_pista,
		datos_mapa_nodo.level_number
	)


func _abrir_nodo_jugable(clave_pista: String, datos_mapa_nodo: RefCounted) -> void:
	var contexto_sesion: Dictionary = datos_mapa_nodo.crear_contexto_sesion(
		clave_pista,
		GameSceneRouter.MAP_SCENE_PATH
	)
	var ruta_json_nodo: String = str(contexto_sesion.get("node_json_path", ""))
	var datos_nodo: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta_json_nodo)
	
	if datos_nodo.is_empty():
		push_warning("MapScene: usando fallback legacy por fallo de JSON.")
		_abrir_escena_jugable(GameSceneRouter.QUESTIONS_SCENE_PATH, contexto_sesion)
		return

	var modo_nodo: String = str(datos_nodo.get("mode", "")).strip_edges()
	var ruta_escena: String = PlayableNodeRouterScript.obtener_escena_jugable(modo_nodo)
	
	if ruta_escena.is_empty():
		push_error("MapScene: No se pudo resolver la escena para el modo: " + modo_nodo)
		_abrir_escena_jugable(GameSceneRouter.QUESTIONS_SCENE_PATH, contexto_sesion)
		return

	contexto_sesion["node_mode"] = modo_nodo
	contexto_sesion["node_data"] = datos_nodo
	_abrir_escena_jugable(ruta_escena, contexto_sesion)


func _abrir_escena_jugable(ruta_escena: String, contexto_sesion: Dictionary) -> void:
	Global.establecer_sesion_nodo_jugable_activo(contexto_sesion)
	if ruta_escena == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(get_tree())
		return
	get_tree().change_scene_to_file(ruta_escena)


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


func _nodo_se_puede_abrir_desde_mapa(datos_mapa_nodo: RefCounted) -> bool:
	if datos_mapa_nodo == null:
		return false
	if not datos_mapa_nodo.tiene_destino_runtime():
		return false
	if datos_mapa_nodo.es_nodo_jugable():
		return true
	return datos_mapa_nodo.tiene_destino_capitulo() and GameTrackCatalog.tiene_pista(
		_obtener_clave_pista_valida(datos_mapa_nodo)
	)


# Progreso -------------------------------------------------------------------
func _nodo_esta_completado(datos_mapa_nodo: RefCounted) -> bool:
	var track_key: String = _obtener_clave_pista_valida(datos_mapa_nodo)
	if datos_mapa_nodo.es_nodo_jugable():
		return Global.es_nodo_jugable_completado(track_key, datos_mapa_nodo.resolver_clave_nodo())
	return Global.es_nivel_completado(track_key, datos_mapa_nodo.level_number)


func _obtener_clave_pista_valida(datos_mapa_nodo: RefCounted) -> String:
	var clave_pista_cruda: String = datos_mapa_nodo.obtener_clave_pista_o_default(DEFAULT_TRACK_KEY)
	if GameTrackCatalog.tiene_pista(clave_pista_cruda):
		return clave_pista_cruda
	return DEFAULT_TRACK_KEY


# Salida ---------------------------------------------------------------------
func _al_pedir_volver() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
