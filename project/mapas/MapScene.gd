extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const AvanceDeNodoScript := preload("res://mapas/logica/AvanceDeNodo.gd")
const AbridorDeNodoJugableScript := preload("res://mapas/logica/AbridorDeNodoJugable.gd")
const MAP_COMPLETION_SCENE := preload("res://mapas/completo/CapituloCompletado.tscn")

const MAP_JSON_PATH := "res://contenido/mapa/celiaquia_mapa.json"
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const MAP_VIEW_SYSTEM_KEY := "map_view"
const MAP_VIEW_SCROLL_VERTICAL_KEY := "scroll_vertical"

var map_id: String = ""
var map_title: String = ""
var track_key_mapa: String = DEFAULT_TRACK_KEY
var nodos_mapa: Array[MapNodeData] = []

@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


# Entrada desde el mapa
func _ready() -> void:
	_conectar_senales()
	cargar_mapa()
	GameSceneRouter.request_scene_preload(
		GameTrackCatalog.obtener_ruta_escena_nivel(track_key_mapa)
	)

	Global.finalizar_partida_de_nodo()
	Global.limpiar_sesion_nodo_jugable_activo()
	actualizar_estados_de_nodos()
	_restaurar_scroll_guardado_del_mapa()

	var nodo_actual: String = Global.consumir_nodo_a_continuar()
	if not nodo_actual.is_empty():
		continuar_desde_nodo(nodo_actual)
		return

	_mostrar_completado_del_mapa_si_corresponde()


# Flujo del mapa
func _conectar_senales() -> void:
	if map_hud != null and map_hud.has_signal("back_requested"):
		map_hud.connect("back_requested", _al_pedir_volver)
	if map_board != null and map_board.has_signal("node_selected"):
		map_board.connect("node_selected", al_seleccionar_nodo)


func cargar_mapa() -> void:
	var result: Dictionary = CargadorDeMapaScript.load_map(MAP_JSON_PATH)
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
	track_key_mapa = _obtener_track_key_valida(str(map_data.get("track_key", DEFAULT_TRACK_KEY)))
	nodos_mapa = []

	var loaded_nodes: Variant = map_data.get("nodes", [])
	if loaded_nodes is Array:
		for raw_node in (loaded_nodes as Array):
			var node_data: MapNodeData = raw_node as MapNodeData
			if node_data != null:
				node_data.track_key = track_key_mapa
				nodos_mapa.append(node_data)


func actualizar_estados_de_nodos() -> void:
	if map_board == null or not map_board.has_method("configurar_nodos"):
		return

	var node_states: Array[Dictionary] = []
	for node_data in nodos_mapa:
		node_states.append(AvanceDeNodoScript.get_node_state(nodos_mapa, node_data))
	map_board.call("configurar_nodos", nodos_mapa, node_states)


func al_seleccionar_nodo(node_data: MapNodeData) -> void:
	if node_data == null or not node_data.is_valid():
		_mostrar_error("No se pudo leer el nodo seleccionado.")
		return

	_guardar_scroll_actual_del_mapa()
	abrir_nodo_del_mapa(node_data)


func abrir_nodo_del_mapa(node_data: MapNodeData) -> void:
	var result: Dictionary = AbridorDeNodoJugableScript.abrir_nodo(
		get_tree(),
		node_data,
		GameSceneRouter.MAP_SCENE_PATH
	)
	if not bool(result.get("ok", false)):
		_mostrar_error(str(result.get("error", "No se pudo abrir el nodo.")))


func continuar_desde_nodo(node_key: String) -> void:
	var next_node: MapNodeData = (
		AvanceDeNodoScript.obtener_siguiente_nodo(nodos_mapa, node_key) as MapNodeData
	)
	if next_node == null:
		volver_al_mapa()
		return
	var next_state: Dictionary = AvanceDeNodoScript.get_node_state(nodos_mapa, next_node)
	if bool(next_state.get("is_completed", false)):
		actualizar_estados_de_nodos()
		_desplazar_a_proximo_disponible()
		return
	abrir_nodo_del_mapa(next_node)


func obtener_nodo_mapa(node_key: String) -> MapNodeData:
	var clean_node_key: String = node_key.strip_edges()
	for node_data in nodos_mapa:
		if node_data.node_key == clean_node_key:
			return node_data
	return null


func volver_al_mapa() -> void:
	actualizar_estados_de_nodos()
	_desplazar_a_proximo_disponible()
	_mostrar_completado_del_mapa_si_corresponde()


# Helpers privados
func _desplazar_a_proximo_disponible() -> void:
	if map_board == null or not map_board.has_method("desplazar_al_primer_nodo_disponible"):
		return
	map_board.call("desplazar_al_primer_nodo_disponible")


func _mostrar_completado_del_mapa_si_corresponde() -> void:
	if not AvanceDeNodoScript.mapa_esta_completado(nodos_mapa, track_key_mapa):
		return
	if _popup_completado_activo():
		return

	var popup_completado: Node = MAP_COMPLETION_SCENE.instantiate()
	if popup_completado == null:
		return
	if popup_completado.has_method("configure_for_track"):
		popup_completado.call("configure_for_track", track_key_mapa)
	add_child(popup_completado)


func _popup_completado_activo() -> bool:
	for child in get_children():
		if child.get_script() != null:
			var path: String = str(child.get_script().get_path())
			if path.ends_with("capitulo_completado.gd"):
				return true
	return false


func _obtener_track_key_valida(raw_track_key: String) -> String:
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
