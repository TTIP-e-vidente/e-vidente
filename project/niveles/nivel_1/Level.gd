extends Node
class_name Level

signal run_completed

const LOG_PREFIX_ARRASTRE := "[ARRASTRE]"
const LOG_PREFIX_ENSENANZA := "[ENSENANZA]"
const LOG_PREFIX_POST_GAME := "[POST_GAME]"
const LOG_PREFIX_TEACHING := "[Teaching]"
const LOG_PREFIX_TEACHING_ASSET := "[TeachingAsset]"
const TEACHING_FALLBACK_TEXT := "Buen trabajo. Elegiste alimentos aptos sin TACC."

## --- Configuración ---

const DEFAULT_TRACK_KEY            := "celiaquia"
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter             := preload("res://niveles/GameSceneRouter.gd")
const ContinuidadDePartidaDeNodoScript := preload(
	"res://mapas/logica/ContinuidadDePartidaDeNodo.gd"
)
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const CargadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/CargadorDeContenidoDeNodo.gd"
)
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const DificultadArrastreScript := preload("res://niveles/nivel_1/DificultadArrastre.gd")
const GameStreakTrackerScript      := preload(
	"res://niveles/progress/GameStreakTracker.gd"
)
const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)
const ContextoSesionDeJuegoScript := preload(
	"res://niveles/progress/ContextoSesionDeJuego.gd"
)
const ContextoFinalizacionDeJuegoScript := preload(
	"res://niveles/progress/ContextoFinalizacionDeJuego.gd"
)
const PresentadorContinuarJuegoScript := preload(
	"res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd"
)
const COMPLETION_BLACK_AND_WHITE_SHADER_PATH := (
	"res://niveles/level_completion_black_and_white.gdshader"
)
const SAVE_ICON_IDLE_PATH := "res://assets-sistema/interfaz/icono-guardar.svg"
const SAVE_ICON_OK_PATH   := "res://assets-sistema/interfaz/icono-guardar-ok.svg"
const COMPLETION_DIM_COLOR := Color(0.62, 0.62, 0.62, 1.0)

## --- Guardado rápido ---

const SAVE_FEEDBACK_DEFAULT_TITLE       := "Guardado local"
const SAVE_FEEDBACK_SUCCESS_TITLE_COLOR := Color(0.215686, 0.337255, 0.231373, 1)
const SAVE_FEEDBACK_SUCCESS_BODY_COLOR  := Color(0.266667, 0.227451, 0.156863, 0.96)
const SAVE_FEEDBACK_ERROR_TITLE_COLOR   := Color(0.568627, 0.184314, 0.141176, 1)
const SAVE_FEEDBACK_ERROR_BODY_COLOR    := Color(0.403922, 0.160784, 0.121569, 0.96)

## --- Exports ---

@export var track_key_override    := ""
@export var background_music_path := DEFAULT_BACKGROUND_MUSIC_PATH
@export_group("Completion")
@export var grayscale_on_completion := true

## --- Nodos de escena ---

@onready var back_button:        Button              = $Atrás
@onready var next_chapter_button: Button             = $Adelante
@onready var adelante_1: Sprite2D					 = $Adelante/adelante1
@onready var adelante_2: Sprite2D 					 = $Adelante/adelante2
@onready var adelante_3: Sprite2D 					 = $Adelante/adelante3
@onready var teaching_sprite:    Sprite2D            = $Ensenanza
@onready var tarjeta_ensenanza_cierre: Control = $TarjetaEnsenanzaCierre
@onready var label_ensenanza_cierre: Label = (
	$TarjetaEnsenanzaCierre/MargenEnsenanzaCierre/LabelEnsenanzaCierre
)
@onready var menu_area:          Area2D              = $Menú
@onready var lupa_area:          Area2D              = $Lupa
@onready var manager_level                           = $ManagerLevel

## Guardado rápido (UI)
@onready var save_progress_button:  Button         = $SaveProgressButton
@onready var save_feedback_backdrop: PanelContainer = $SaveFeedbackBackdrop
@onready var save_feedback_title: Label = (
	$SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackTitle
)
@onready var save_feedback_label: Label = (
	$SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackLabel
)

## --- Estado runtime ---
var save_feedback_timer:   Timer  = null
var active_track_key:      String = ""
var _post_game_streak_feedback: Dictionary = {}
var _post_game_flow_state: Dictionary = {}
var _current_run_completion_handled := false
var _completion_visual_original_materials: Dictionary = {}
var _completion_visual_original_modulates: Dictionary = {}
var _contexto_nodo_mapa: Dictionary = {}
var current_node: MapNodeData = null
var _datos_nodo_mapa: Dictionary = {}
var _usa_flujo_mapa := false
var _pertenece_a_partida_de_nodo := false
var _nodo_actual := ""
var _json_path_nodo_actual := ""
var _ruta_escena_retorno := ""
var _track_key_contexto := ""
var _ya_continuo := false
var _completion_black_and_white_shader: Shader = null
var _save_icon_idle: Texture2D = null
var _save_icon_ok: Texture2D = null

@onready var _indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego
@onready var _continuar_juego = $ContinuarJuego

# Entrada del nivel
func _ready() -> void:
	_cargar_recursos_runtime()
	_conectar_continuar_juego()
	iniciar_flujo_del_nivel()
	_configurar_indicador_de_progreso_de_juego()
	configurar_retroalimentacion_de_guardado()


func _cargar_recursos_runtime() -> void:
	_completion_black_and_white_shader = load(COMPLETION_BLACK_AND_WHITE_SHADER_PATH) as Shader
	_save_icon_idle = load(SAVE_ICON_IDLE_PATH) as Texture2D
	_save_icon_ok = load(SAVE_ICON_OK_PATH) as Texture2D


func _conectar_continuar_juego() -> void:
	if _continuar_juego == null:
		return
	if _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.connect("continuar_solicitado", Callable(self, "_al_solicitar_continuar"))



## --- Arranque ---

func iniciar_flujo_del_nivel() -> void:
	cargar_contenido_del_nivel()
	resolver_pista_activa()
	reiniciar_estado_de_partida()
	iniciar_runtime_de_arrastre()
	_reproducir_audio_nivel()


## --- Contexto jugable ------------------------------------------------------

func cargar_contenido_del_nivel() -> void:
	_reiniciar_contexto_jugable_del_nivel()
	_contexto_nodo_mapa = ContextoSesionDeJuegoScript.normalizar_contexto_jugable(
		ContextoSesionDeJuegoScript.obtener_contexto_jugable_actual(),
		track_key_override.strip_edges(),
		1,
		GameSceneRouter.MAP_SCENE_PATH
	)
	if _contexto_nodo_mapa.is_empty():
		return

	_aplicar_contexto_jugable_del_nivel(_contexto_nodo_mapa)
	if not str(_contexto_nodo_mapa.get("activity_id", "")).strip_edges().is_empty():
		cargar_contenido_del_nivel_desde_contexto(_contexto_nodo_mapa)
	elif not _json_path_nodo_actual.is_empty():
		cargar_contenido_del_nivel_desde_json(_json_path_nodo_actual)

	_usa_flujo_mapa = bool(_contexto_nodo_mapa.get("came_from_map", false))


func _reiniciar_contexto_jugable_del_nivel() -> void:
	current_node = null
	_contexto_nodo_mapa = {}
	_datos_nodo_mapa = {}
	_usa_flujo_mapa = false
	_pertenece_a_partida_de_nodo = false
	_nodo_actual = ""
	_json_path_nodo_actual = ""
	_track_key_contexto = ""
	_ruta_escena_retorno = GameSceneRouter.MAP_SCENE_PATH


func _aplicar_contexto_jugable_del_nivel(contexto_jugable: Dictionary) -> void:
	_pertenece_a_partida_de_nodo = bool(
		contexto_jugable.get("pertenece_a_partida_de_nodo", false)
	)
	_nodo_actual = str(contexto_jugable.get("node_key", "")).strip_edges()
	_track_key_contexto = str(contexto_jugable.get("track_key", "")).strip_edges()
	_json_path_nodo_actual = str(contexto_jugable.get("json_path", "")).strip_edges()
	_ruta_escena_retorno = str(
		contexto_jugable.get("return_to", GameSceneRouter.MAP_SCENE_PATH)
	).strip_edges()
	if _ruta_escena_retorno.is_empty():
		_ruta_escena_retorno = GameSceneRouter.MAP_SCENE_PATH

	var titulo_nodo: String = str(
		contexto_jugable.get("node_title", contexto_jugable.get("titulo_nodo", ""))
	).strip_edges()
	var modo_jugable: String = str(
		contexto_jugable.get("mode", contexto_jugable.get("node_mode", ""))
	).strip_edges()
	var numero_nivel_jugable: int = int(
		contexto_jugable.get("level_number", contexto_jugable.get("nivel_id", 1))
	)

	current_node = MapNodeDataScript.new()
	current_node.node_key = _nodo_actual
	current_node.title = titulo_nodo
	current_node.mode = modo_jugable
	current_node.json_path = _json_path_nodo_actual
	current_node.track_key = _track_key_contexto
	current_node.index = max(0, numero_nivel_jugable - 1)


func resolver_pista_activa() -> void:
	var configured_key := track_key_override.strip_edges()
	if not _track_key_contexto.is_empty():
		active_track_key = _track_key_contexto
	else:
		active_track_key = configured_key if not configured_key.is_empty() else DEFAULT_TRACK_KEY


## --- HUD / progreso --------------------------------------------------------

func _configurar_indicador_de_progreso_de_juego() -> void:
	if _indicador_de_progreso_de_juego == null:
		return
	var contexto: Dictionary = ContextoSesionDeJuegoScript.obtener_modelo_indicador_actual()
	_indicador_de_progreso_de_juego.show()
	_indicador_de_progreso_de_juego.actualizar(
		str(contexto.get("titulo", "")).strip_edges(),
		int(contexto.get("actual", 1)),
		int(contexto.get("total", 1))
	)


## --- Carga de contenido ----------------------------------------------------

func cargar_contenido_del_nivel_desde_json(json_path: String) -> void:
	var clean_path: String = json_path.strip_edges()
	if clean_path.is_empty():
		push_error("Level: falta json_path para cargar el nivel.")
		return

	var result: Dictionary = CargadorDeContenidoDeNodoScript.cargar_contenido_nodo(clean_path)
	if not bool(result.get("ok", false)):
		push_error("Level: %s" % str(result.get("error", "No se pudo cargar el JSON del nivel.")))
		return

	var datos_nodo: Dictionary = result.get("data", {})
	_datos_nodo_mapa = datos_nodo.duplicate(true)


func cargar_contenido_del_nivel_desde_contexto(contexto_jugable: Dictionary) -> void:
	var result: Dictionary = NodeContentLoaderScript.load_from_context(contexto_jugable)
	if not bool(result.get("ok", false)):
		push_error(
			"Level: %s"
			% str(result.get("error", "No se pudo cargar el contenido del nivel."))
		)
		return

	var datos_nodo: Dictionary = result.get("data", {})
	_datos_nodo_mapa = datos_nodo.duplicate(true)


## --- Estado inicial --------------------------------------------------------

func reiniciar_estado_de_partida() -> void:
	_post_game_streak_feedback = {}
	_post_game_flow_state = {}
	_current_run_completion_handled = false
	_ya_continuo = false
	Item_level.is_dragging = null
	_restaurar_estado_posterior_finalizacion()
	next_chapter_button.disabled = true


## --- Runtime de arrastre ---------------------------------------------------

func iniciar_runtime_de_arrastre() -> void:
	if manager_level == null:
		push_error("Level no pudo inicializar el runtime de ManagerLevel.")
		return
	_aplicar_dificultad_de_arrastre()
	# Intentar iniciar arrastre desde JSON oficial; si falla, usar flujo legacy.
	if _iniciar_arrastre_desde_json_si_corresponde():
		return
	_iniciar_arrastre_legacy()


func _iniciar_arrastre_legacy() -> void:
	manager_level.iniciar_nivel_sesion(active_track_key, self)
	var nivel_numero_resuelto: int = _numero_nivel_valido(active_track_key)
	if nivel_numero_resuelto > 0:
		SaveManager.establecer_reanudar_en_nivel(active_track_key, nivel_numero_resuelto)


## --- Soporte: iniciar arrastre desde JSON -------------------------------
func _iniciar_arrastre_desde_json_si_corresponde() -> bool:
	if not _puede_iniciar_arrastre_desde_json():
		return false

	var nodo_datos: Dictionary = _obtener_datos_de_arrastre_del_nodo()
	if nodo_datos.is_empty():
		return false

	var conversion: Dictionary = CargadorDeContenidoDeNodoScript.convertir_arrastre_a_runtime(
		nodo_datos
	)
	if not bool(conversion.get("ok", false)):
		push_warning("Level: JSON no válido para arrastre: %s" % str(conversion.get("error", "")))
		return false

	_log_arrastre_cargado(conversion.get("data", {}))

	return _iniciar_runtime_de_arrastre_desde_datos(conversion.get("data", {}))


func _puede_iniciar_arrastre_desde_json() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	if current_node == null:
		return false
	return str(current_node.mode).strip_edges() == "drag_drop"


func _obtener_datos_de_arrastre_del_nodo() -> Dictionary:
	if not _datos_nodo_mapa.is_empty():
		return _datos_nodo_mapa

	var ruta_json: String = _json_path_nodo_actual
	if ruta_json.is_empty():
		return {}

	var result: Dictionary = CargadorDeContenidoDeNodoScript.cargar_contenido_nodo(ruta_json)
	if not bool(result.get("ok", false)):
		push_warning(
			"Level: no se pudo leer JSON de arrastre: %s" % str(result.get("error", ""))
		)
		return {}

	return result.get("data", {})


func _iniciar_runtime_de_arrastre_desde_datos(contenido_arrastre: Dictionary) -> bool:
	if manager_level == null or not manager_level.has_method("iniciar_desde_datos_de_arrastre"):
		push_warning("ManagerLevel no soporta iniciar desde JSON; usando flujo legacy.")
		return false

	var inicio_arrastre_ok: bool = bool(
		manager_level.iniciar_desde_datos_de_arrastre(active_track_key, contenido_arrastre, self)
	)
	if not inicio_arrastre_ok:
		push_warning("Level: no se pudo inicializar el arrastre desde JSON; usando flujo legacy.")
	return inicio_arrastre_ok


func _aplicar_dificultad_de_arrastre() -> void:
	if (
		manager_level == null
		or not manager_level.has_method("establecer_configuracion_de_dificultad_arrastre")
	):
		return
	if not _pertenece_a_partida_de_nodo:
		manager_level.establecer_configuracion_de_dificultad_arrastre({})
		return
	var dificultad_actual: int = Global.obtener_dificultad_del_juego_actual()
	manager_level.establecer_configuracion_de_dificultad_arrastre(
		_construir_configuracion_de_dificultad_arrastre(dificultad_actual)
	)


func _construir_configuracion_de_dificultad_arrastre(dificultad: int) -> Dictionary:
	return {
		"dificultad": dificultad,
		"elementos_maximos": DificultadArrastreScript.limitar_elementos_por_dificultad(
			dificultad
		),
		"distractores_maximos": (
			DificultadArrastreScript.obtener_cantidad_de_distractores_por_dificultad(
				dificultad
			)
		),
		"mostrar_ayuda_visual": DificultadArrastreScript.deberia_mostrar_ayuda_visual(
			dificultad
		),
	}


## --- Recursos visuales y feedback inicial ---------------------------------

func _reproducir_audio_nivel() -> void:
	if background_music_path.strip_edges().is_empty():
		return
	var ruta_musica: String = background_music_path.strip_edges()
	MusicManager.reproducir_musica(ruta_musica)


func configurar_retroalimentacion_de_guardado() -> void:
	save_progress_button.tooltip_text = "Guardar este avance en el dispositivo"
	save_progress_button.icon = _save_icon_idle
	save_feedback_backdrop.visible = false
	save_feedback_title.text = SAVE_FEEDBACK_DEFAULT_TITLE
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	save_feedback_label.text = ""
	if is_instance_valid(save_feedback_timer):
		return
	save_feedback_timer = Timer.new()
	save_feedback_timer.name = "SaveFeedbackResetTimer"
	save_feedback_timer.one_shot = true
	save_feedback_timer.wait_time = 3.0
	save_feedback_timer.timeout.connect(_on_guardar_retroalimentacion_timeout)
	add_child(save_feedback_timer)


func _exit_tree() -> void:
	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
	_ocultar_continuacion()


# Finalización de partida
## --- Navegación y gameplay ---

func _on_atras_presionado() -> void:
	if es_partida_completada():
		return
	if _pertenece_a_partida_de_nodo:
		_cancelar_partida_de_nodo()
		return
	if _usa_flujo_mapa:
		_return_to_map_scene()
		return
	if active_track_key == DEFAULT_TRACK_KEY:
		GameSceneRouter.go_to_map(get_tree())
	else:
		GameSceneRouter.go_to_track_book(get_tree(), active_track_key)


func es_partida_completada() -> bool:
	return _current_run_completion_handled


func completar_partida_actual() -> void:
	_finalizar_partida()


func _finalizar_partida() -> void:
	if _current_run_completion_handled:
		return

	var track_key := active_track_key
	var level_number := _numero_nivel_valido(track_key)
	if level_number <= 0:
		return
	var activity_id: String = _obtener_activity_id_actual()
	var teaching_key: String = _obtener_teaching_key_actual()
	print(
		"%s completed_drag activity=%s key=%s"
		% [LOG_PREFIX_TEACHING, activity_id, teaching_key]
	)
	if teaching_key.is_empty():
		print(
			"%s missing teaching data for activity=%s"
			% [LOG_PREFIX_TEACHING, activity_id]
		)
	if _debe_mostrar_ensenanza_antes_de_continuar_partida():
		print(
			LOG_PREFIX_ARRASTRE,
			" completado=true llamando_ensenanza=true teaching_key=",
			_obtener_teaching_key_actual()
		)
		_mostrar_ensenanza_del_nivel()
		return
	_finalizar_partida_normal(track_key, level_number)


func _debe_mostrar_ensenanza_antes_de_continuar_partida() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())


func _mostrar_ensenanza_del_nivel() -> void:
	_current_run_completion_handled = true
	mostrar_estado_de_finalizacion()
	_mostrar_ensenanza_de_cierre()
	mostrar_continuacion()
	run_completed.emit()


func _finalizar_partida_normal(track_key: String, level_number: int) -> void:
	_current_run_completion_handled = true
	mostrar_estado_de_finalizacion()

	var previous_streak: Dictionary = Global.obtener_estado_racha()
	guardar_progreso_de_finalizacion(track_key, level_number)
	var updated_streak: Dictionary = Global.obtener_estado_racha()
	construir_flujo_post_game(level_number, previous_streak, updated_streak)
	if _usa_flujo_mapa:
		_mostrar_ensenanza_de_cierre()
		mostrar_continuacion()
		run_completed.emit()
		return

	mostrar_continuacion()
	run_completed.emit()


func _continuar_partida_de_nodo_si_corresponde() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	var habia_siguiente: bool = ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())
	var continuo: bool = ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(
		get_tree(),
		Callable(),
		Callable(self, "_limpiar_estado_local_de_partida_en_nivel")
	)
	if not continuo and habia_siguiente:
		push_error("[POST_GAME] No se pudo avanzar: falta siguiente juego o target inválido.")
	return continuo


func _limpiar_estado_local_de_partida_en_nivel() -> void:
	_pertenece_a_partida_de_nodo = false


func guardar_progreso_de_finalizacion(track_key: String, level_number: int) -> void:
	if _usa_flujo_mapa:
		_guardar_progreso_de_mapa()
		Global.registrar_actividad_racha(
			"map_node_completed",
			{
				"track_key": track_key,
				"level_number": level_number,
				"node_key": _nodo_actual,
			}
		)
		SaveManager.guardar_progreso_en_disco()
		return

	Global.marcar_nivel_completado(track_key, level_number)
	Global.registrar_actividad_racha(
		"level_completed",
		{"track_key": track_key, "level_number": level_number}
	)
	SaveManager.registrar_nivel_completado(track_key, level_number)


func mostrar_estado_de_finalizacion() -> void:
	_bloquear_completado_partida()

func _mostrar_completado_partida_retroalimentacion() -> void:
	_ocultar_boton_adelante_anterior()

func _on_adelante_presionado() -> void:
	if not es_partida_completada():
		return
	_al_solicitar_continuar()


func mostrar_continuacion() -> void:
	_ya_continuo = false
	_ocultar_boton_adelante_anterior()
	_asegurar_cierre_visible_para_continuacion()
	PresentadorContinuarJuegoScript.mostrar(
		_continuar_juego,
		_hay_siguiente_juego_de_partida(),
		5
	)


func _asegurar_cierre_visible_para_continuacion() -> void:
	if _esta_visible_ensenanza_de_cierre():
		return
	_mostrar_ensenanza_de_cierre()


func _esta_visible_ensenanza_de_cierre() -> bool:
	if is_instance_valid(teaching_sprite) and teaching_sprite.visible:
		return true
	return is_instance_valid(tarjeta_ensenanza_cierre) and tarjeta_ensenanza_cierre.visible


func _hay_siguiente_juego_de_partida() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())


func _on_timer_siguiente_nodo_timeout() -> void:
	_al_solicitar_continuar()


func continuar_al_siguiente_nodo() -> void:
	_al_solicitar_continuar()


func _al_solicitar_continuar() -> void:
	if _ya_continuo:
		return

	_ya_continuo = true
	print(LOG_PREFIX_ENSENANZA, " cerrada=true llamando_post_game=true")
	_ocultar_continuacion()
	_continuar_despues_de_ensenanza(true)


func _continuar_despues_de_ensenanza(timer_finished: bool) -> void:
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	var indice_actual: int = int(juego_actual.get("indice_juego_actual", 0)) + 1
	var total_juegos: int = int(juego_actual.get("total_juegos", 0))
	var hay_siguiente := false
	if _pertenece_a_partida_de_nodo:
		hay_siguiente = ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())
	print(LOG_PREFIX_POST_GAME, " contexto_recibido=", juego_actual)
	print(
		LOG_PREFIX_POST_GAME,
		" juego_actual=",
		indice_actual,
		" total=",
		total_juegos,
		" hay_siguiente=",
		hay_siguiente
	)
	if _continuar_partida_de_nodo_si_corresponde():
		return
	if not _has_post_game_flow_state():
		if _usa_flujo_mapa:
			_continuar_flujo_mapa_legacy()
			return
		GameSceneRouter.go_to_mode_selector(get_tree())
		return

	PostGameFlowControllerScript.navigate_after_teaching(
		get_tree(),
		_take_post_game_flow_state(),
		_take_post_game_streak_feedback(),
		timer_finished
	)


func _on_teaching_finished(timer_finished: bool) -> void:
	_continuar_despues_de_ensenanza(timer_finished)


## --- Continuación desde mapa ---

func _ocultar_continuacion() -> void:
	PresentadorContinuarJuegoScript.ocultar(_continuar_juego)


func _ocultar_boton_adelante_anterior() -> void:
	if is_instance_valid(next_chapter_button):
		next_chapter_button.hide()
		next_chapter_button.disabled = true
	if is_instance_valid(adelante_1):
		adelante_1.hide()
	if is_instance_valid(adelante_2):
		adelante_2.hide()
	if is_instance_valid(adelante_3):
		adelante_3.hide()


func _guardar_progreso_de_mapa() -> void:
	if _nodo_actual.is_empty():
		return
	Global.marcar_nodo_jugable_completado(active_track_key, _nodo_actual)


func construir_flujo_post_game(
	level_number: int,
	previous_streak: Dictionary,
	updated_streak: Dictionary
) -> void:
	var completion_context: Dictionary = ContextoFinalizacionDeJuegoScript.construir(
		"level",
		active_track_key,
		level_number,
		Global.obtener_pista_nivel_cantidad(active_track_key),
		active_track_key == DEFAULT_TRACK_KEY,
		_usa_flujo_mapa,
		_nodo_actual,
		_ruta_escena_retorno,
		"Level.construir_flujo_post_game"
	)
	_post_game_streak_feedback = GameStreakTrackerScript.build_feedback(
		previous_streak,
		updated_streak,
		true
	)
	_post_game_flow_state = PostGameFlowControllerScript.build_post_game_flow_state(
		previous_streak,
		updated_streak,
		completion_context,
		_post_game_streak_feedback
	)


func _has_post_game_flow_state() -> bool:
	return not _post_game_flow_state.is_empty()


func _take_post_game_flow_state() -> Dictionary:
	var post_game_flow_state: Dictionary = _post_game_flow_state.duplicate(true)
	_post_game_flow_state = {}
	return post_game_flow_state


func _take_post_game_streak_feedback() -> Dictionary:
	var post_game_streak_feedback: Dictionary = _post_game_streak_feedback.duplicate(true)
	_post_game_streak_feedback = {}
	return post_game_streak_feedback


func _return_to_map_scene() -> void:
	_ocultar_continuacion()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_retorno
	)


func _cancelar_partida_de_nodo() -> void:
	_ocultar_continuacion()
	Global.finalizar_partida_de_nodo()
	Global.limpiar_sesion_nodo_jugable_activo()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_retorno
	)
## --- Guardado rápido ---

func _on_guardar_progreso_boton_presionado() -> void:
	if es_partida_completada():
		return
	if manager_level == null or not is_instance_valid(manager_level):
		_mostrar_guardar_retroalimentacion(
			"No se pudo guardar",
			"No se pudo acceder al runtime del nivel para guardar.",
			false
		)
		return

	var track_key := active_track_key
	var resolved_level_number := _numero_nivel_valido(track_key)
	if resolved_level_number <= 0:
		_mostrar_guardar_retroalimentacion(
			"No se pudo guardar",
			"No se pudo resolver el capitulo activo para guardar.",
			false
		)
		return

	var saved_positive_count: int = manager_level.almacenar_parcial_nivel_estado(track_key)
	SaveManager.establecer_reanudar_en_nivel(track_key, resolved_level_number)
	SaveManager.registrar_guardado_manual()
	if SaveManager.tiene_error_guardado():
		var error: String = SaveManager.obtener_error_ultimo_guardado()
		_mostrar_guardar_retroalimentacion(
			"No se pudo guardar",
			error if not error.is_empty() else "Reintenta de nuevo en unos segundos",
			false
		)
		return
	_mostrar_guardar_exito_retroalimentacion(saved_positive_count)


func _mostrar_guardar_exito_retroalimentacion(saved_positive_count: int) -> void:
	var title := "Guardado parcial" if saved_positive_count > 0 else SAVE_FEEDBACK_DEFAULT_TITLE
	var saved_time: String = SaveManager.obtener_ultimo_guardado_en().get_slice(" ", 1)
	var time_line := (
		"Guardado a las %s" % saved_time
		if not saved_time.is_empty()
		else "Guardado en este dispositivo"
	)
	var detail_lines: Array[String] = [time_line]
	var run_line: String = manager_level.obtener_actual_partida_guardar_label()
	if not run_line.is_empty():
		detail_lines.append(run_line)
	detail_lines.append(manager_level.formatear_parcial_guardar_progreso(saved_positive_count))
	_mostrar_guardar_retroalimentacion(title, "\n".join(detail_lines), true)


## --- Racha y feedback post-partida ---

func _mostrar_guardar_retroalimentacion(title: String, message: String, success: bool) -> void:
	_mostrar_retroalimentacion_tarjeta(
		title,
		message,
		SAVE_FEEDBACK_SUCCESS_TITLE_COLOR if success else SAVE_FEEDBACK_ERROR_TITLE_COLOR,
		SAVE_FEEDBACK_SUCCESS_BODY_COLOR if success else SAVE_FEEDBACK_ERROR_BODY_COLOR
	)
	save_progress_button.icon = _save_icon_ok if success else _save_icon_idle


func _continuar_flujo_mapa_legacy() -> void:
	if _ya_continuo:
		return
	_ya_continuo = true
	_ocultar_continuacion()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_retorno,
		_nodo_actual
	)


func _mostrar_retroalimentacion_tarjeta(
	title: String,
	message: String,
	title_color: Color,
	body_color: Color
) -> void:
	save_feedback_title.text = title
	save_feedback_label.text = message
	save_feedback_title.modulate = title_color
	save_feedback_label.modulate = body_color

	save_feedback_backdrop.modulate = Color(1, 1, 1, 0.0)
	save_feedback_backdrop.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(save_feedback_backdrop, "modulate:a", 1.0, 0.22)

	if is_instance_valid(save_feedback_timer):
		save_feedback_timer.stop()
		save_feedback_timer.start()


func _reiniciar_guardar_retroalimentacion_visual_estado() -> void:
	save_progress_button.icon = _save_icon_idle
	save_feedback_backdrop.visible = false


func _on_guardar_retroalimentacion_timeout() -> void:
	if not is_inside_tree():
		return
	_reiniciar_guardar_retroalimentacion_visual_estado()


func _bloquear_completado_partida() -> void:
	Item_level.is_dragging = null
	_establecer_interacciones_jugabilidad_habilitadas(false)
	_ocultar_boton_adelante_anterior()
	_ocultar_ensenanza_textual()
	if is_instance_valid(teaching_sprite):
		teaching_sprite.hide()
	_aplicar_finalizacion_visual_estado()


func _restaurar_estado_posterior_finalizacion() -> void:
	restaurar_finalizacion_visual_estado()
	_establecer_interacciones_jugabilidad_habilitadas(true)
	_ocultar_boton_adelante_anterior()
	if is_instance_valid(teaching_sprite):
		teaching_sprite.hide()
	_ocultar_ensenanza_textual()
	_establecer_visibilidad_indicador_de_progreso(true)
	_ocultar_continuacion()


func _ocultar_ensenanza_textual() -> void:
	if is_instance_valid(teaching_sprite):
		teaching_sprite.hide()
	if is_instance_valid(tarjeta_ensenanza_cierre):
		tarjeta_ensenanza_cierre.hide()
	if is_instance_valid(label_ensenanza_cierre):
		label_ensenanza_cierre.text = ""


func _establecer_visibilidad_indicador_de_progreso(visible: bool) -> void:
	if _indicador_de_progreso_de_juego == null:
		return
	if visible:
		_indicador_de_progreso_de_juego.show()
		return
	_indicador_de_progreso_de_juego.hide()


func _establecer_interacciones_jugabilidad_habilitadas(enabled: bool) -> void:
	if is_instance_valid(back_button):
		back_button.disabled = not enabled
		back_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if is_instance_valid(save_progress_button):
		save_progress_button.disabled = not enabled
		save_progress_button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	if is_instance_valid(menu_area):
		menu_area.set_deferred("monitoring", enabled)
		menu_area.set_deferred("monitorable", enabled)
	if is_instance_valid(lupa_area):
		lupa_area.set_deferred("monitoring", enabled)
		lupa_area.set_deferred("monitorable", enabled)
	if (
		is_instance_valid(manager_level)
		and manager_level.has_method("establecer_tiempo_ejecucion_elementos_interactuable")
	):
		manager_level.establecer_tiempo_ejecucion_elementos_interactuable(enabled)


func _aplicar_finalizacion_visual_estado() -> void:
	if not grayscale_on_completion or _completion_black_and_white_shader == null:
		return

	var grayscale_material := ShaderMaterial.new()
	grayscale_material.shader = _completion_black_and_white_shader
	for runtime_node in find_children("*", "", true, false):
		if not runtime_node is CanvasItem:
			continue
		if _deberia_omitir_finalizacion_visual(runtime_node):
			continue

		var canvas_item := runtime_node as CanvasItem
		var node_id := canvas_item.get_instance_id()
		if not _completion_visual_original_modulates.has(node_id):
			_completion_visual_original_modulates[node_id] = canvas_item.modulate
		var original_modulate: Color = canvas_item.modulate
		canvas_item.modulate = Color(
			COMPLETION_DIM_COLOR.r,
			COMPLETION_DIM_COLOR.g,
			COMPLETION_DIM_COLOR.b,
			original_modulate.a
		)

		if canvas_item is Sprite2D or canvas_item is AnimatedSprite2D:
			if not _completion_visual_original_materials.has(node_id):
				_completion_visual_original_materials[node_id] = canvas_item.material
			canvas_item.material = grayscale_material


func _deberia_omitir_finalizacion_visual(runtime_node: Node) -> bool:
	if runtime_node == self:
		return true
	if is_instance_valid(next_chapter_button) and (
		runtime_node == next_chapter_button or next_chapter_button.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(teaching_sprite) and runtime_node == teaching_sprite:
		return true
	if is_instance_valid(tarjeta_ensenanza_cierre) and (
		runtime_node == tarjeta_ensenanza_cierre
		or tarjeta_ensenanza_cierre.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(save_feedback_backdrop) and (
		runtime_node == save_feedback_backdrop
		or save_feedback_backdrop.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(_continuar_juego) and (
		runtime_node == _continuar_juego or _continuar_juego.is_ancestor_of(runtime_node)
	):
		return true
	return false


## --- Enseñanza: mostrar imagen de asset -------------------------------
func _hay_textura_de_ensenanza() -> bool:
	return is_instance_valid(teaching_sprite) and teaching_sprite.texture != null


func _mostrar_ensenanza_de_cierre() -> void:
	_establecer_visibilidad_indicador_de_progreso(false)
	var activity_id: String = _obtener_activity_id_actual()
	var teaching_key: String = _obtener_teaching_key_actual()
	print("%s show key=%s" % [LOG_PREFIX_TEACHING, teaching_key])
	if _hay_textura_de_ensenanza():
		if is_instance_valid(tarjeta_ensenanza_cierre):
			tarjeta_ensenanza_cierre.hide()
		if is_instance_valid(teaching_sprite):
			teaching_sprite.show()
		print("%s fallback=false" % LOG_PREFIX_TEACHING_ASSET)
		print("%s fallback=false" % LOG_PREFIX_TEACHING)
		return
	if teaching_key.is_empty():
		print(
			"%s missing teaching data for activity=%s"
			% [LOG_PREFIX_TEACHING, activity_id]
		)
	print(
		"%s missing asset key=%s fallback=true"
		% [LOG_PREFIX_TEACHING, teaching_key]
	)
	print("%s fallback=true" % LOG_PREFIX_TEACHING_ASSET)
	_mostrar_ensenanza_textual(TEACHING_FALLBACK_TEXT)


func _log_arrastre_cargado(datos_arrastre: Dictionary) -> void:
	var contexto: Dictionary = Global.obtener_contexto_de_progreso_de_juego()
	var activity_id: String = str(
		datos_arrastre.get("node_key", datos_arrastre.get("id", ""))
	).strip_edges()
	var teaching_key: String = str(datos_arrastre.get("teaching_key", "")).strip_edges()
	print(
		LOG_PREFIX_ARRASTRE,
		" juego_actual=",
		int(contexto.get("actual", 1)),
		" total=",
		int(contexto.get("total", 1)),
		" id=",
		activity_id,
		" teaching_key=",
		teaching_key
	)
	print(
		"%s activity=%s key=%s"
		% [LOG_PREFIX_TEACHING, activity_id, teaching_key]
	)
	print(
		"%s runtime_has_teaching_key=%s"
		% [LOG_PREFIX_TEACHING, str(not teaching_key.is_empty())]
	)


func _obtener_teaching_key_actual() -> String:
	var contenido: Variant = _datos_nodo_mapa.get("content", {})
	if contenido is Dictionary:
		var teaching_key: String = _leer_teaching_key_de_diccionario(contenido as Dictionary)
		if not teaching_key.is_empty():
			return teaching_key
	var top_level_teaching_key: String = _leer_teaching_key_de_diccionario(_datos_nodo_mapa)
	if not top_level_teaching_key.is_empty():
		return top_level_teaching_key
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	var teaching_key: String = _leer_teaching_key_de_diccionario(juego_actual)
	if not teaching_key.is_empty():
		return teaching_key
	return _leer_teaching_key_de_diccionario(_contexto_nodo_mapa)


func _mostrar_ensenanza_textual(texto: String) -> void:
	if is_instance_valid(teaching_sprite):
		teaching_sprite.hide()
	if is_instance_valid(label_ensenanza_cierre):
		label_ensenanza_cierre.text = texto
	if is_instance_valid(tarjeta_ensenanza_cierre):
		tarjeta_ensenanza_cierre.show()
		return
	push_warning("Level: no hay tarjeta de ensenanza para mostrar fallback textual.")


func _leer_teaching_key_de_diccionario(datos: Dictionary) -> String:
	for clave_campo in ["teaching_key", "ensenanza", "ensenanza_key", "clave_ensenanza"]:
		var teaching_key: String = str(datos.get(clave_campo, "")).strip_edges()
		if not teaching_key.is_empty():
			return teaching_key
	return ""


func _obtener_activity_id_actual() -> String:
	var activity_id: String = str(_contexto_nodo_mapa.get("activity_id", "")).strip_edges()
	if not activity_id.is_empty():
		return activity_id
	activity_id = str(
		_datos_nodo_mapa.get("id", _datos_nodo_mapa.get("node_key", ""))
	).strip_edges()
	if not activity_id.is_empty():
		return activity_id
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	activity_id = str(
		juego_actual.get("activity_id", juego_actual.get("id", ""))
	).strip_edges()
	if not activity_id.is_empty():
		return activity_id
	return str(juego_actual.get("node_key", "")).strip_edges()


func restaurar_finalizacion_visual_estado() -> void:
	if (
		_completion_visual_original_materials.is_empty()
		and _completion_visual_original_modulates.is_empty()
	):
		return

	for runtime_node in find_children("*", "", true, false):
		if not runtime_node is CanvasItem:
			continue

		var canvas_item := runtime_node as CanvasItem
		var node_id := canvas_item.get_instance_id()
		if _completion_visual_original_modulates.has(node_id):
			canvas_item.modulate = _completion_visual_original_modulates[node_id]
		if _completion_visual_original_materials.has(node_id):
			canvas_item.material = _completion_visual_original_materials[node_id]

	_completion_visual_original_materials.clear()
	_completion_visual_original_modulates.clear()


func _numero_nivel_valido(track_key: String) -> int:
	var level_count := Global.obtener_pista_nivel_cantidad(track_key)
	if level_count <= 0:
		return 0
	return clampi(Global.current_level, 1, level_count)

func _actual_nivel_numero() -> int:
	return int(Global.current_level)
