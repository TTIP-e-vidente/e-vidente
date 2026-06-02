# PUBLICO_TRAINEE
# Dueño visual del mapa. Muestra nodos, racha y perfil.
# Selecciona un nodo y delega el flujo jugable en NodoRuntime.
extends Node2D


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const AvanceDeNodoScript := preload("res://mapas/logica/AvanceDeNodo.gd")
const AbridorDeNodoJugableScript := preload("res://mapas/logica/AbridorDeNodoJugable.gd")
const MAP_COMPLETION_SCENE_PATH := "res://mapas/completo/CapituloCompletado.tscn"
const FINALIZACION_PARTIDA_SCENE := "res://mapas/finalizacion_partida.tscn"
const MAP_SCENE_PATH := "res://mapas/MapScene.tscn"

const MAP_JSON_PATH := "res://contenido/mapa/celiaquia_mapa.json"
const DEFAULT_TRACK_KEY := GameTrackCatalog.TRACK_CELIAQUIA
const MAP_VIEW_SYSTEM_KEY := "map_view"
const MAP_VIEW_SCROLL_VERTICAL_KEY := "scroll_vertical"
const FlujoDeNodoJugableScript := preload("res://flow/map/flujo_de_nodo_jugable.gd")

var map_id: String = ""
var map_title: String = ""
var track_key_mapa: String = DEFAULT_TRACK_KEY
var nodos_mapa: Array[MapNodeData] = []
var layout_config: MapLayoutConfig = null
var _flujo_de_nodo: FlujoDeNodoJugable = null  # gestiona selección de nodo desde el mapa

@onready var map_hud: CanvasLayer = $MapHud
@onready var map_board: Node2D = $MapBoard


# Entrada desde el mapa
func _ready() -> void:
	_flujo_de_nodo = FlujoDeNodoJugableScript.new()
	_flujo_de_nodo.apertura_fallida.connect(_mostrar_error)
	_conectar_senales()
	cargar_mapa()
	GameSceneRouter.request_scene_preload(
		GameTrackCatalog.obtener_ruta_escena_nivel(track_key_mapa)
	)

	Global.finalizar_partida_de_nodo()
	Global.limpiar_sesion_nodo_jugable_activo()
	actualizar_estados_de_nodos()
	call_deferred("_restaurar_scroll_guardado_del_mapa")

	if await _mostrar_finalizacion_de_nodo_si_corresponde():
		return

	var nodo_actual: String = Global.consumir_nodo_a_continuar()
	if not nodo_actual.is_empty():
		continuar_desde_nodo(nodo_actual)
		return

	_mostrar_completado_del_mapa_si_corresponde()


func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	if not is_node_ready() or not visible:
		return
	# Solo refrescar visuales al hacerse visible; la verificación de mapa completo
	# ocurre explícitamente en _ready() y volver_al_mapa(), no en cada cambio de visibilidad.
	actualizar_estados_de_nodos()


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
	layout_config = map_data.get("layout_config", null) as MapLayoutConfig
	nodos_mapa = []

	var loaded_nodes: Variant = map_data.get("nodes", [])
	if loaded_nodes is Array:
		for raw_node in (loaded_nodes as Array):
			var node_data: MapNodeData = raw_node as MapNodeData
			if node_data != null:
				node_data.track_key = track_key_mapa
				nodos_mapa.append(node_data)

	# Pasar config de layout al MapBoard (si lo tiene).
	if map_board != null and map_board.has_method("configurar_nodos"):
		var parsed_layout_config: Variant = map_data.get("layout_config", null)
		if parsed_layout_config is MapLayoutConfig:
			map_board.set("layout_config", parsed_layout_config)


func actualizar_estados_de_nodos() -> void:
	if map_board == null or not map_board.has_method("configurar_nodos"):
		return
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	var node_progress: Dictionary = {}
	if save_manager != null and save_manager.has_method("get_all_node_progress"):
		node_progress = save_manager.call("get_all_node_progress")

	_sincronizar_completados_al_global(node_progress)
	var node_states: Array[Dictionary] = _construir_estados_de_nodos(node_progress)
	map_board.call("configurar_nodos", nodos_mapa, node_states, layout_config)
	if map_board.has_method("refresh_progress_from_save"):
		map_board.call("refresh_progress_from_save")


func al_seleccionar_nodo(node_data: MapNodeData) -> void:
	if node_data == null or not node_data.is_valid():
		_mostrar_error("No se pudo leer el nodo seleccionado.")
		return

	_guardar_scroll_actual_del_mapa()
	_flujo_de_nodo.seleccionar_nodo(get_tree(), nodos_mapa, node_data)


func abrir_nodo_del_mapa(node_data: MapNodeData) -> void:
	var result: Dictionary = AbridorDeNodoJugableScript.abrir_nodo(
		get_tree(),
		node_data,
		MAP_SCENE_PATH
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


func _sincronizar_completados_al_global(node_progress: Dictionary) -> void:
	for node_data in nodos_mapa:
		var key: String = node_data.node_key.strip_edges()
		var saved: Dictionary = _progreso_guardado(node_progress, key)
		if bool(saved.get("completed", false)):
			Global.marcar_nodo_jugable_completado(track_key_mapa, key)


func _construir_estados_de_nodos(node_progress: Dictionary) -> Array[Dictionary]:
	var node_states: Array[Dictionary] = []
	for node_data in nodos_mapa:
		var state: Dictionary = AvanceDeNodoScript.get_node_state(nodos_mapa, node_data)
		var saved: Dictionary = _progreso_guardado(node_progress, node_data.node_key)
		if not saved.is_empty():
			_aplicar_progreso_guardado(state, saved)
		node_states.append(state)
	return node_states


func _progreso_guardado(node_progress: Dictionary, node_key: String) -> Dictionary:
	var key: String = node_key.strip_edges()
	if key.is_empty() or not node_progress.has(key):
		return {}
	var np: Variant = node_progress[key]
	return np as Dictionary if np is Dictionary else {}


func _aplicar_progreso_guardado(state: Dictionary, saved: Dictionary) -> void:
	state["best_percent"] = float(saved.get("best_percent", 0.0))
	var fallback_accuracy: float = float(saved.get("best_percent", 0.0)) * 100.0
	state["best_accuracy"] = float(saved.get("best_accuracy", fallback_accuracy))
	if bool(saved.get("completed", false)):
		state["is_completed"] = true
		state["visual_state"] = AvanceDeNodoScript.STATE_COMPLETED
		state["can_play"] = true


func _mostrar_finalizacion_de_nodo_si_corresponde() -> bool:
	if not Global.hay_ultima_finalizacion():
		return false
	await TransicionEscenas.change_scene(FINALIZACION_PARTIDA_SCENE)
	return true


func _mostrar_completado_del_mapa_si_corresponde() -> void:
	if not AvanceDeNodoScript.mapa_esta_completado(nodos_mapa, track_key_mapa):
		return
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("ya_se_mostro_recompensa_del_mapa"):
		if bool(save_manager.call("ya_se_mostro_recompensa_del_mapa", map_id)):
			return
	if _popup_completado_activo():
		return
	var completion_scene: PackedScene = load(MAP_COMPLETION_SCENE_PATH) as PackedScene
	if completion_scene == null:
		push_error("MapScene: No se pudo cargar CapituloCompletado.tscn")
		return
	var popup: Node = completion_scene.instantiate()
	if popup == null:
		push_error("MapScene: No se pudo instanciar CapituloCompletado.tscn")
		return
	if popup.has_method("configure_for_track"):
		popup.call("configure_for_track", track_key_mapa)
	add_child(popup)
	if save_manager != null and save_manager.has_method("marcar_recompensa_del_mapa_como_vista"):
		save_manager.call("marcar_recompensa_del_mapa_como_vista", map_id)


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
