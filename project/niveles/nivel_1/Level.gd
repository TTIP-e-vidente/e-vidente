extends Node
class_name Level

signal run_completed

## --- Configuración ---

const DEFAULT_TRACK_KEY            := "celiaquia"
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter             := preload("res://niveles/GameSceneRouter.gd")
const ContinuidadDePartidaDeNodoScript := preload(
	"res://mapas/core/ContinuidadDePartidaDeNodo.gd"
)
const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
const NodeContentLoaderScript := preload("res://sistemas/contenido/NodeContentLoader.gd")
const DificultadArrastreScript := preload("res://niveles/nivel_1/DificultadArrastre.gd")
const GameStreakTrackerScript      := preload(
	"res://niveles/progress/GameStreakTracker.gd"
)
const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)
const RUTA_ESCENA_CONTINUADOR := "res://interface/components/ContinueCountdown.tscn"
const COMPLETION_BLACK_AND_WHITE_SHADER_PATH := "res://niveles/level_completion_black_and_white.gdshader"
const SAVE_ICON_IDLE_PATH := "res://assets-sistema/interfaz/icono-guardar.svg"
const SAVE_ICON_OK_PATH   := "res://assets-sistema/interfaz/icono-guardar-ok.svg"
const COMPLETION_DIM_COLOR := Color(0.72, 0.72, 0.72, 1.0)

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
@onready var capa_ensenanza_texto: Control = (
	get_node_or_null("CanvasEnsenanzaTexto/CapaEnsenanzaTexto") as Control
)
@onready var label_ensenanza_texto: Label = (
	get_node_or_null(
		"CanvasEnsenanzaTexto/CapaEnsenanzaTexto/CenterContainer/PanelEnsenanzaTexto/MarginContainer/VBoxContainer/LabelEnsenanzaTexto"
	) as Label
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
var _escena_continuador: PackedScene = null
var _completion_black_and_white_shader: Shader = null
var _save_icon_idle: Texture2D = null
var _save_icon_ok: Texture2D = null
var continuador = null

@onready var _indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego

# Entrada del nivel
func _ready() -> void:
	_cargar_recursos_runtime()
	configurar_continuador()
	iniciar_flujo_del_nivel()
	_configurar_indicador_de_progreso_de_juego()
	configurar_retroalimentacion_de_guardado()


func _cargar_recursos_runtime() -> void:
	_escena_continuador = load(RUTA_ESCENA_CONTINUADOR) as PackedScene
	_completion_black_and_white_shader = load(COMPLETION_BLACK_AND_WHITE_SHADER_PATH) as Shader
	_save_icon_idle = load(SAVE_ICON_IDLE_PATH) as Texture2D
	_save_icon_ok = load(SAVE_ICON_OK_PATH) as Texture2D



## --- Arranque ---

func iniciar_flujo_del_nivel() -> void:
	cargar_contenido_del_nivel()
	resolver_pista_activa()
	reiniciar_estado_de_partida()
	iniciar_runtime_de_arrastre()
	_reproducir_audio_nivel()


# Flujo feliz del nivel
func cargar_contenido_del_nivel() -> void:
	_reiniciar_contexto_jugable_del_nivel()
	_contexto_nodo_mapa = _obtener_contexto_jugable_actual()
	if _contexto_nodo_mapa.is_empty():
		return

	_aplicar_contexto_jugable_del_nivel(_contexto_nodo_mapa)
	if not _json_path_nodo_actual.is_empty():
		cargar_contenido_del_nivel_desde_json(_json_path_nodo_actual)

	_usa_flujo_mapa = not _nodo_actual.is_empty()


func _reiniciar_contexto_jugable_del_nivel() -> void:
	current_node = null
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
	_json_path_nodo_actual = _leer_json_path_jugable(contexto_jugable)
	_ruta_escena_retorno = GameSceneRouter.read_return_to(
		contexto_jugable,
		GameSceneRouter.MAP_SCENE_PATH
	)
	if _ruta_escena_retorno.is_empty():
		_ruta_escena_retorno = GameSceneRouter.MAP_SCENE_PATH

	current_node = MapNodeDataScript.new()
	current_node.node_key = _nodo_actual
	current_node.title = str(contexto_jugable.get("node_title", "")).strip_edges()
	current_node.mode = _leer_modo_jugable(contexto_jugable)
	current_node.json_path = _json_path_nodo_actual
	current_node.track_key = _track_key_contexto
	current_node.index = max(0, _leer_numero_de_nivel_jugable(contexto_jugable) - 1)


func resolver_pista_activa() -> void:
	var configured_key := track_key_override.strip_edges()
	if not _track_key_contexto.is_empty():
		active_track_key = _track_key_contexto
	else:
		active_track_key = configured_key if not configured_key.is_empty() else DEFAULT_TRACK_KEY


func reiniciar_estado_de_partida() -> void:
	_post_game_streak_feedback = {}
	_post_game_flow_state = {}
	_current_run_completion_handled = false
	_ya_continuo = false
	Item_level.is_dragging = null
	_restaurar_estado_posterior_finalizacion()
	next_chapter_button.disabled = true


func iniciar_runtime_de_arrastre() -> void:
	if manager_level == null:
		push_error("Level no pudo inicializar el runtime de ManagerLevel.")
		return
	_aplicar_dificultad_de_arrastre()
	# Intentar iniciar arrastre desde JSON oficial; si falla, usar flujo legacy.
	if _intentar_iniciar_arrastre_desde_json():
		return
	_iniciar_arrastre_legacy()


func _iniciar_arrastre_legacy() -> void:
	manager_level.iniciar_nivel_sesion(active_track_key, self)
	var nivel_numero_resuelto: int = _numero_nivel_valido(active_track_key)
	if nivel_numero_resuelto > 0:
		SaveManager.establecer_reanudar_en_nivel(active_track_key, nivel_numero_resuelto)


## --- Soporte: iniciar arrastre desde JSON -------------------------------
func _intentar_iniciar_arrastre_desde_json() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	if current_node == null:
		return false
	if str(current_node.mode).strip_edges() != "drag_drop":
		return false

	# ya puede estar cargado por cargar_contenido_del_nivel_desde_json
	var nodo_datos: Dictionary = _datos_nodo_mapa
	if nodo_datos.is_empty():
		var ruta := _json_path_nodo_actual
		if ruta.is_empty():
			return false
		var result: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(ruta)
		if not bool(result.get("ok", false)):
			push_warning("Level: no se pudo leer JSON de arrastre: %s" % str(result.get("error", "")))
			return false
		nodo_datos = result.get("data", {})

	var conversion: Dictionary = NodeContentLoaderScript.convertir_arrastre_a_runtime(nodo_datos)
	if not bool(conversion.get("ok", false)):
		push_warning("Level: JSON no válido para arrastre: %s" % str(conversion.get("error", "")))
		return false

	var contenido_arrastre: Dictionary = conversion.get("data", {})
	# delegar a ManagerLevel si implementa el entrypoint
	if manager_level != null and manager_level.has_method("iniciar_desde_datos_de_arrastre"):
		var inicio_arrastre_ok: bool = bool(
			manager_level.iniciar_desde_datos_de_arrastre(active_track_key, contenido_arrastre, self)
		)
		if not inicio_arrastre_ok:
			push_warning("Level: no se pudo inicializar el arrastre desde JSON; usando flujo legacy.")
		return inicio_arrastre_ok
	# si no existe el método en ManagerLevel, fallback
	push_warning("ManagerLevel no soporta iniciar desde JSON; usando flujo legacy.")
	return false


func _aplicar_dificultad_de_arrastre() -> void:
	if manager_level == null or not manager_level.has_method("establecer_configuracion_de_dificultad_arrastre"):
		return
	if not _pertenece_a_partida_de_nodo:
		manager_level.establecer_configuracion_de_dificultad_arrastre({})
		return
	var dificultad_actual: int = Global.obtener_dificultad_del_juego_actual()
	manager_level.establecer_configuracion_de_dificultad_arrastre(
		{
			"dificultad": dificultad_actual,
			"elementos_maximos": DificultadArrastreScript.limitar_elementos_por_dificultad(
				dificultad_actual
			),
			"distractores_maximos": DificultadArrastreScript.obtener_cantidad_de_distractores_por_dificultad(
				dificultad_actual
			),
			"mostrar_ayuda_visual": DificultadArrastreScript.deberia_mostrar_ayuda_visual(
				dificultad_actual
			),
		}
	)


func _obtener_contexto_jugable_actual() -> Dictionary:
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	if not juego_actual.is_empty():
		return juego_actual
	return Global.obtener_sesion_nodo_jugable_activo()


func _configurar_indicador_de_progreso_de_juego() -> void:
	if _indicador_de_progreso_de_juego == null:
		return
	var contexto: Dictionary = Global.obtener_contexto_de_progreso_de_juego()
	var titulo_juego: String = str(contexto.get("titulo", contexto.get("titulo_nodo", ""))).strip_edges()
	var indice_juego_actual: int = int(contexto.get("actual", contexto.get("indice_juego_actual", 1)))
	var total_juegos: int = int(contexto.get("total", contexto.get("total_juegos", 1)))
	_indicador_de_progreso_de_juego.actualizar(
		titulo_juego,
		indice_juego_actual,
		total_juegos
	)


func cargar_contenido_del_nivel_desde_json(json_path: String) -> void:
	var clean_path: String = json_path.strip_edges()
	if clean_path.is_empty():
		push_error("Level: falta json_path para cargar el nivel.")
		return

	var result: Dictionary = NodeContentLoaderScript.cargar_contenido_nodo(clean_path)
	if not bool(result.get("ok", false)):
		push_error("Level: %s" % str(result.get("error", "No se pudo cargar el JSON del nivel.")))
		return

	var datos_nodo: Dictionary = result.get("data", {})
	_datos_nodo_mapa = datos_nodo.duplicate(true)


func _leer_json_path_jugable(contexto_sesion: Dictionary) -> String:
	var clean_path: String = str(contexto_sesion.get("json_path", "")).strip_edges()
	if not clean_path.is_empty():
		return clean_path
	return str(contexto_sesion.get("node_json_path", "")).strip_edges()


func _leer_numero_de_nivel_jugable(contexto_sesion: Dictionary) -> int:
	return int(contexto_sesion.get("level_number", contexto_sesion.get("nivel_id", 1)))


func _leer_modo_jugable(contexto_sesion: Dictionary) -> String:
	return str(contexto_sesion.get("mode", contexto_sesion.get("node_mode", ""))).strip_edges()


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
	if continuador != null:
		continuador.detener()


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
	if _debe_mostrar_ensenanza_antes_de_continuar_partida():
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

	_mostrar_completado_partida_retroalimentacion()
	run_completed.emit()


func _continuar_partida_de_nodo_si_corresponde() -> bool:
	if not _pertenece_a_partida_de_nodo:
		return false
	return ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(
		get_tree(),
		Callable(),
		Callable(self, "_limpiar_estado_local_de_partida_en_nivel")
	)


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
	var chapter_fijo := _actual_nivel_numero()
	while is_inside_tree() and es_partida_completada() and _actual_nivel_numero() == chapter_fijo:
		adelante_2.show()
		await get_tree().create_timer(0.60).timeout
		adelante_2.hide()
		await get_tree().create_timer(0.60).timeout
		adelante_1.show()
		await get_tree().create_timer(0.60).timeout
		adelante_1.hide()
		await get_tree().create_timer(0.60).timeout
		adelante_3.show()
		await get_tree().create_timer(0.60).timeout
		adelante_3.hide()
		await get_tree().create_timer(0.60).timeout

func _on_adelante_presionado() -> void:
	if not es_partida_completada():
		return
	_continuar_despues_de_ensenanza(true)


func mostrar_continuacion() -> void:
	_ya_continuo = false
	next_chapter_button.hide()
	continuador.iniciar(5)


func _on_timer_siguiente_nodo_timeout() -> void:
	continuar_al_siguiente_nodo()


func continuar_al_siguiente_nodo() -> void:
	if _ya_continuo:
		return

	_ya_continuo = true
	if continuador != null:
		continuador.detener()
	_continuar_despues_de_ensenanza(true)


func _continuar_despues_de_ensenanza(timer_finished: bool) -> void:
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

func configurar_continuador() -> void:
	if _escena_continuador == null:
		return
	continuador = _escena_continuador.instantiate()
	add_child(continuador)
	_ubicar_continuador()
	continuador.continuar_solicitado.connect(continuar_al_siguiente_nodo)
	continuador.ocultar()


func _ubicar_continuador() -> void:
	var rect_boton: Rect2 = next_chapter_button.get_global_rect()
	var tamano_continuador: Vector2 = continuador.size
	if tamano_continuador == Vector2.ZERO:
		tamano_continuador = continuador.get_combined_minimum_size()
	var pos := rect_boton.get_center() - (tamano_continuador * 0.5)
	var viewport_size := get_viewport().get_visible_rect().size
	const MARGEN := 8.0
	pos.x = clampf(pos.x, MARGEN, viewport_size.x - tamano_continuador.x - MARGEN)
	pos.y = clampf(pos.y, MARGEN, viewport_size.y - tamano_continuador.y - MARGEN)
	continuador.position = pos


func _guardar_progreso_de_mapa() -> void:
	if _nodo_actual.is_empty():
		return
	Global.marcar_nodo_jugable_completado(active_track_key, _nodo_actual)


func construir_flujo_post_game(
	level_number: int,
	previous_streak: Dictionary,
	updated_streak: Dictionary
) -> void:
	var completion_context: Dictionary = _build_completion_context(level_number)
	_post_game_streak_feedback = GameStreakTrackerScript.build_feedback(
		previous_streak,
		updated_streak,
		true
	)
	# La escena solo arma contexto; el controller lo transforma en flow_state.
	_post_game_flow_state = PostGameFlowControllerScript.build_post_game_flow_state(
		previous_streak,
		updated_streak,
		completion_context,
		_post_game_streak_feedback
	)


func _build_completion_context(level_number: int) -> Dictionary:
	return {
		"source": "level",
		"level": _build_level_completion_context(level_number),
		"map": _build_map_completion_context(),
		"navigation": _build_navigation_completion_context(),
		"debug": _build_completion_debug_context(),
	}


func _build_level_completion_context(level_number: int) -> Dictionary:
	return {
		"track_key": active_track_key,
		"number": level_number,
		"track_level_count": Global.obtener_pista_nivel_cantidad(active_track_key),
		"is_default_track": active_track_key == DEFAULT_TRACK_KEY,
	}


func _build_map_completion_context() -> Dictionary:
	var node_key: Variant = null
	if _usa_flujo_mapa and not _nodo_actual.is_empty():
		node_key = _nodo_actual
	return {
		"came_from_map": _usa_flujo_mapa,
		"node_key": node_key,
	}


func _build_navigation_completion_context() -> Dictionary:
	return {
		"return_to": _ruta_escena_retorno,
	}


func _build_completion_debug_context() -> Dictionary:
	return {
		"created_by": "Level._build_completion_context",
	}


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
	if continuador != null:
		continuador.detener()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_retorno
	)


func _cancelar_partida_de_nodo() -> void:
	if continuador != null:
		continuador.detener()
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
	if continuador != null:
		continuador.detener()
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
	next_chapter_button.disabled = false
	_ocultar_ensenanza_textual()
	if is_instance_valid(teaching_sprite) and teaching_sprite.texture != null:
		teaching_sprite.show()
	elif is_instance_valid(teaching_sprite):
		teaching_sprite.hide()
	_aplicar_finalizacion_visual_estado()


func _restaurar_estado_posterior_finalizacion() -> void:
	restaurar_finalizacion_visual_estado()
	_establecer_interacciones_jugabilidad_habilitadas(true)
	next_chapter_button.show()
	teaching_sprite.hide()
	_ocultar_ensenanza_textual()
	if continuador != null:
		continuador.ocultar()


func _ocultar_ensenanza_textual() -> void:
	if is_instance_valid(capa_ensenanza_texto):
		capa_ensenanza_texto.hide()
	if is_instance_valid(label_ensenanza_texto):
		label_ensenanza_texto.text = ""


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
	if is_instance_valid(capa_ensenanza_texto) and (
		runtime_node == capa_ensenanza_texto or capa_ensenanza_texto.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(label_ensenanza_texto) and (
		runtime_node == label_ensenanza_texto or label_ensenanza_texto.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(save_feedback_backdrop) and (
		runtime_node == save_feedback_backdrop
		or save_feedback_backdrop.is_ancestor_of(runtime_node)
	):
		return true
	if is_instance_valid(continuador) and (
		runtime_node == continuador or continuador.is_ancestor_of(runtime_node)
	):
		return true
	return false


## --- Enseñanza: mostrar imagen o texto -------------------------------
func _hay_textura_de_ensenanza() -> bool:
	return is_instance_valid(teaching_sprite) and teaching_sprite.texture != null


func _mostrar_imagen_de_ensenanza() -> void:
	_ocultar_ensenanza_textual()
	if is_instance_valid(teaching_sprite) and teaching_sprite.texture != null:
		teaching_sprite.show()


func _mostrar_texto_de_ensenanza(mensaje: String) -> void:
	var mensaje_visible: String = str(mensaje).strip_edges()
	if mensaje_visible.is_empty():
		mensaje_visible = _obtener_mensaje_fallback_de_ensenanza()
	if is_instance_valid(teaching_sprite):
		teaching_sprite.hide()
	if not is_instance_valid(capa_ensenanza_texto) or not is_instance_valid(label_ensenanza_texto):
		push_warning("CapaEnsenanzaTexto o LabelEnsenanzaTexto no encontrados; no se puede mostrar texto de enseñanza.")
		return
	# Mostrar el mensaje en una capa dedicada para que no compita con la bandeja inferior.
	label_ensenanza_texto.modulate = Color(1, 1, 1, 1)
	label_ensenanza_texto.text = mensaje_visible
	capa_ensenanza_texto.show()


func _obtener_mensaje_de_ensenanza_desde_runtime() -> String:
	if not is_instance_valid(manager_level):
		return ""
	var nivel_recurso: LevelResource = manager_level.level_resource
	if nivel_recurso == null:
		return ""
	var payload: Dictionary = {}
	if nivel_recurso.has_method("get"):
		# level_resource podría ser Resource; intentar acceder a mechanic_payload
		pass
	payload = nivel_recurso.mechanic_payload if nivel_recurso and nivel_recurso.mechanic_payload else {}

	var es_exito: bool = true
	if is_instance_valid(manager_level) and manager_level.has_method("tiene_completado_actual_partida"):
		es_exito = bool(manager_level.tiene_completado_actual_partida())

	if es_exito:
		var msg_exito: String = str(payload.get("mensaje_exito", "")).strip_edges()
		if not msg_exito.is_empty():
			return msg_exito
	else:
		var msg_error: String = str(payload.get("mensaje_error", "")).strip_edges()
		if not msg_error.is_empty():
			return msg_error

	return ""


func _obtener_mensaje_fallback_de_ensenanza() -> String:
	return "¡Buen trabajo! Completaste este desafío."


func _mostrar_ensenanza_de_cierre() -> void:
	# Decide si mostrar imagen, texto del runtime o fallback.
	if _hay_textura_de_ensenanza():
		_mostrar_imagen_de_ensenanza()
		return

	var mensaje_runtime: String = _obtener_mensaje_de_ensenanza_desde_runtime()
	if not str(mensaje_runtime).strip_edges().is_empty():
		_mostrar_texto_de_ensenanza(mensaje_runtime)
		return

	_mostrar_texto_de_ensenanza(_obtener_mensaje_fallback_de_ensenanza())


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
