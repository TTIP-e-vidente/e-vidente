extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const MapContentLoaderScript := preload("res://sistemas/contenido/MapContentLoader.gd")
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const MapProgressScript := preload("res://mapas/core/MapProgress.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const PlayableNodeRouterScript := preload("res://mapas/core/PlayableNodeRouter.gd")
const MAP_COMPLETION_SCENE := preload("res://mapas/completo/CapituloCompletado.tscn")
const MAP_JSON_PATH := "res://niveles/mapas/celiaquia_mapa.json"
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const MAP_VIEW_SYSTEM_KEY := "map_view"
const MAP_VIEW_SCROLL_VERTICAL_KEY := "scroll_vertical"

var nodos_mapa: Array = []
var track_key_mapa: String = DEFAULT_TRACK_KEY

@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


func _ready() -> void:
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _al_pedir_volver)

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


func cargar_mapa() -> void:
	var resultado: Dictionary = MapContentLoaderScript.cargar_mapa(MAP_JSON_PATH)
	if not bool(resultado.get("ok", false)):
		nodos_mapa = []
		track_key_mapa = DEFAULT_TRACK_KEY
		_mostrar_error(str(resultado.get("error", "No se pudo cargar el mapa.")))
		return

	var datos_mapa: Dictionary = resultado.get("data", {})
	var track_key_json: String = str(datos_mapa.get("track_key", DEFAULT_TRACK_KEY)).strip_edges()
	if track_key_json.is_empty() or not GameTrackCatalog.tiene_pista(track_key_json):
		track_key_mapa = DEFAULT_TRACK_KEY
	else:
		track_key_mapa = track_key_json

	var nodos_cargados: Variant = datos_mapa.get("nodes", [])
	nodos_mapa = []
	if nodos_cargados is Array:
		nodos_mapa = (nodos_cargados as Array).duplicate(true)


func mostrar_nodos() -> void:
	var nodos_visuales: Array[Node2D] = _obtener_nodos_visuales_mapa()
	var seleccionar_nodo := Callable(self, "al_seleccionar_nodo")
	var cantidad_a_mostrar: int = mini(nodos_visuales.size(), nodos_mapa.size())

	if nodos_visuales.size() != nodos_mapa.size():
		push_warning(
			"MapScene: cantidad de nodos visuales (%d) distinta a nodos_mapa (%d)."
			% [nodos_visuales.size(), nodos_mapa.size()]
		)

	for indice in range(cantidad_a_mostrar):
		var nodo_mapa: Dictionary = nodos_mapa[indice]
		var nodo_visual: Node2D = nodos_visuales[indice]
		var datos_nodo: RefCounted = _crear_datos_nodo_mapa(nodo_mapa, nodo_visual, indice)
		if datos_nodo == null:
			nodo_visual.hide()
			continue

		var nodo_actual: String = str(nodo_mapa.get("node_key", "")).strip_edges()
		var esta_completado: bool = Global.es_nodo_jugable_completado(
			track_key_mapa,
			nodo_actual
		)
		var esta_desbloqueado: bool = MapProgressScript.nodo_esta_desbloqueado(
			nodos_mapa,
			indice,
			track_key_mapa,
			esta_completado
		)

		nodo_visual.show()
		nodo_visual.configurar(datos_nodo, esta_desbloqueado, esta_completado)
		if not nodo_visual.is_connected("nodo_seleccionado", seleccionar_nodo):
			nodo_visual.connect("nodo_seleccionado", seleccionar_nodo)

	for indice in range(cantidad_a_mostrar, nodos_visuales.size()):
		nodos_visuales[indice].hide()


func _obtener_nodos_visuales_mapa() -> Array[Node2D]:
	var nodos_visuales: Array[Node2D] = []
	for nodo_visual in _obtener_nodos_del_tablero():
		var datos_nodo: RefCounted = MapNodeDataScript.desde_nodo_mapa(nodo_visual)
		if datos_nodo == null:
			nodo_visual.hide()
			continue
		nodos_visuales.append(nodo_visual)
	return nodos_visuales


func _crear_datos_nodo_mapa(
	nodo_mapa: Dictionary,
	nodo_visual: Node2D,
	indice: int
) -> RefCounted:
	var datos_visual: RefCounted = MapNodeDataScript.desde_nodo_mapa(nodo_visual)
	if datos_visual == null:
		return null

	var datos_mapa_nodo: RefCounted = MapNodeDataScript.desde_diccionario(nodo_mapa)
	var datos_nodo: RefCounted = datos_visual.duplicar_datos()
	datos_nodo.node_id = indice + 1
	datos_nodo.question_number = indice + 1
	datos_nodo.track_key = track_key_mapa
	datos_nodo.label_text = datos_mapa_nodo.obtener_titulo()
	datos_nodo.node_key = datos_mapa_nodo.obtener_clave_nodo()
	datos_nodo.node_json_path = datos_mapa_nodo.obtener_ruta_json()
	return datos_nodo


func _mostrar_completado_del_mapa_si_corresponde() -> void:
	if not MapProgressScript.mapa_esta_completado(nodos_mapa, track_key_mapa):
		return

	var popup_completado: Node = MAP_COMPLETION_SCENE.instantiate()
	if popup_completado == null:
		return
	if popup_completado.has_method("configure_for_track"):
		popup_completado.call("configure_for_track", track_key_mapa)
	add_child(popup_completado)


func obtener_contenedor_de_nodos() -> Node2D:
	if map_board != null and map_board.has_method("obtener_contenedor_nodos"):
		return map_board.call("obtener_contenedor_nodos") as Node2D
	return null


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


## --- Flujo de nodo jugable -------------------------------------------------

func al_seleccionar_nodo(destino_seleccionado: Variant) -> void:
	_guardar_scroll_actual_del_mapa()
	var datos_nodo: RefCounted = MapNodeDataScript.desde_seleccion(destino_seleccionado)
	if datos_nodo == null:
		_mostrar_error("No se pudo leer el nodo seleccionado.")
		return

	var nodo_actual: String = datos_nodo.obtener_clave_nodo()
	var nodo_mapa: Dictionary = obtener_nodo_mapa(nodo_actual)
	if nodo_mapa.is_empty():
		_mostrar_error("No se encontro el nodo %s en el mapa." % nodo_actual)
		return

	abrir_nodo_del_mapa(nodo_mapa)


func obtener_nodo_mapa(nodo_actual: String) -> Dictionary:
	for nodo_mapa in nodos_mapa:
		if str(nodo_mapa.get("node_key", "")).strip_edges() == nodo_actual:
			return nodo_mapa
	return {}


func abrir_nodo_del_mapa(nodo_mapa: Dictionary) -> void:
	var datos_mapa_nodo: RefCounted = MapNodeDataScript.desde_diccionario(nodo_mapa)
	var ruta_json_nodo: String = datos_mapa_nodo.obtener_ruta_json()
	var resultado: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta_json_nodo)

	if not bool(resultado.get("ok", false)):
		_mostrar_error(str(resultado.get("error", "No se pudo cargar el nodo.")))
		return

	var datos_nodo: Dictionary = resultado.get("data", {})
	var modo: String = str(datos_nodo.get("mode", "")).strip_edges()
	var ruta_escena: String = PlayableNodeRouterScript.obtener_escena_jugable(modo)

	if ruta_escena.is_empty():
		_mostrar_error("No existe escena para el modo.")
		return

	var contexto_sesion: Dictionary = _crear_contexto_sesion(nodo_mapa, ruta_json_nodo, datos_nodo)
	abrir_escena_jugable(ruta_escena, contexto_sesion)


func abrir_escena_jugable(ruta_escena: String, contexto_sesion: Dictionary) -> void:
	Global.establecer_sesion_nodo_jugable_activo(contexto_sesion)
	if ruta_escena == GameSceneRouter.QUESTIONS_SCENE_PATH:
		GameSceneRouter.go_to_questions(get_tree())
		return
	get_tree().change_scene_to_file(ruta_escena)


func continuar_desde_nodo(nodo_actual: String) -> void:
	var siguiente_nodo: Dictionary = obtener_siguiente_nodo(nodo_actual)

	if siguiente_nodo.is_empty():
		volver_al_mapa()
		return

	abrir_nodo_del_mapa(siguiente_nodo)


func obtener_siguiente_nodo(nodo_actual: String) -> Dictionary:
	return MapProgressScript.obtener_siguiente_nodo(nodos_mapa, nodo_actual)


func _crear_contexto_sesion(
	nodo_mapa: Dictionary,
	ruta_json_nodo: String,
	datos_nodo: Dictionary
) -> Dictionary:
	var contexto_sesion: Dictionary = MapNodeDataScript.desde_diccionario(
		nodo_mapa
	).crear_contexto_sesion(GameSceneRouter.MAP_SCENE_PATH)
	var nodo_actual: String = str(contexto_sesion.get("node_key", "")).strip_edges()
	var indice: int = MapProgressScript.obtener_indice_nodo(nodos_mapa, nodo_actual)
	contexto_sesion["track_key"] = track_key_mapa
	contexto_sesion["nivel_id"] = max(0, indice + 1)
	contexto_sesion["node_json_path"] = ruta_json_nodo
	contexto_sesion["node_mode"] = str(datos_nodo.get("mode", "")).strip_edges()
	contexto_sesion["node_data"] = datos_nodo
	return contexto_sesion


func volver_al_mapa() -> void:
	_mostrar_completado_del_mapa_si_corresponde()


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
