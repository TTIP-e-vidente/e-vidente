extends Node
class_name Level

signal run_completed

## --- Configuración ---

const DEFAULT_TRACK_KEY            := "celiaquia"
const DEFAULT_BACKGROUND_MUSIC_PATH := (
	"res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
)

const GameSceneRouter             := preload("res://niveles/GameSceneRouter.gd")
const GameStreakTrackerScript      := preload(
	"res://niveles/progress/GameStreakTracker.gd"
)
const GameStreakDebugScript := preload(
	"res://niveles/progress/GameStreakDebug.gd"
)
const ContinueCountdownScene := preload("res://ui/components/ContinueCountdown.tscn")
const COMPLETION_BLACK_AND_WHITE_SHADER := preload(
	"res://niveles/level_completion_black_and_white.gdshader"
)
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK   := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")
const COMPLETION_DIM_COLOR := Color(0.72, 0.72, 0.72, 1.0)
const CONTINUADOR_POSICION_FLECHA_DERECHA := Vector2(882.0, 632.0)

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
var _pending_streak_feedback: Dictionary = {}
var _current_run_completion_handled := false
var _completion_visual_original_materials: Dictionary = {}
var _completion_visual_original_modulates: Dictionary = {}
var _contexto_nodo_mapa: Dictionary = {}
var _datos_nodo_mapa: Dictionary = {}
var _usa_flujo_mapa := false
var _nodo_actual := ""
var _ruta_escena_retorno := ""
var _track_key_contexto := ""
var _ya_continuo := false
var continuador = null


func _ready() -> void:
	_crear_continuador()
	_iniciar_flujo_nivel()
	_configurar_retroalimentacion_guardado_rapida()



## --- Arranque ---

func _iniciar_flujo_nivel() -> void:
	_cargar_contexto_sesion()
	var configured_key := track_key_override.strip_edges()
	if not _track_key_contexto.is_empty():
		active_track_key = _track_key_contexto
	else:
		active_track_key = configured_key if not configured_key.is_empty() else DEFAULT_TRACK_KEY
	_pending_streak_feedback = {}
	_current_run_completion_handled = false
	_ya_continuo = false
	Item_level.is_dragging = null
	_restaurar_estado_posterior_finalizacion()
	next_chapter_button.disabled = true
	_reproducir_audio_nivel()
	if manager_level == null:
		push_error("Level no pudo inicializar el runtime de ManagerLevel.")
	else:
		manager_level.iniciar_nivel_sesion(active_track_key, self)
	var resolved_level_number := _numero_nivel_valido(active_track_key)
	if resolved_level_number > 0:
		SaveManager.establecer_reanudar_en_nivel(active_track_key, resolved_level_number)


func _cargar_contexto_sesion() -> void:
	_contexto_nodo_mapa = Global.obtener_sesion_nodo_jugable_activo()
	_datos_nodo_mapa = {}
	_usa_flujo_mapa = false
	_nodo_actual = ""
	_track_key_contexto = ""
	_ruta_escena_retorno = GameSceneRouter.MAP_SCENE_PATH

	if _contexto_nodo_mapa.is_empty():
		return

	_nodo_actual = str(_contexto_nodo_mapa.get("node_key", "")).strip_edges()
	_track_key_contexto = str(_contexto_nodo_mapa.get("track_key", "")).strip_edges()
	_ruta_escena_retorno = str(
		_contexto_nodo_mapa.get("return_scene_path", GameSceneRouter.MAP_SCENE_PATH)
	).strip_edges()
	if _ruta_escena_retorno.is_empty():
		_ruta_escena_retorno = GameSceneRouter.MAP_SCENE_PATH

	var datos_nodo: Variant = _contexto_nodo_mapa.get("node_data", {})
	if datos_nodo is Dictionary:
		configurar_desde_datos_nodo(datos_nodo)

	_usa_flujo_mapa = not _nodo_actual.is_empty()


func configurar_desde_datos_nodo(datos_nodo: Dictionary) -> void:
	_datos_nodo_mapa = datos_nodo.duplicate(true)


func _reproducir_audio_nivel() -> void:
	if background_music_path.strip_edges().is_empty():
		return
	var ruta_musica: String = background_music_path.strip_edges()
	MusicManager.reproducir_musica(ruta_musica)


func _configurar_retroalimentacion_guardado_rapida() -> void:
	save_progress_button.tooltip_text = "Guardar este avance en el dispositivo"
	save_progress_button.icon = SAVE_ICON_IDLE
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


## --- Navegación y gameplay ---

func _on_atras_presionado() -> void:
	if es_corrida_completado():
		return
	if _usa_flujo_mapa:
		Global.limpiar_sesion_nodo_jugable_activo()
		get_tree().change_scene_to_file(_ruta_escena_retorno)
		return
	if active_track_key == DEFAULT_TRACK_KEY:
		GameSceneRouter.go_to_map(get_tree())
	else:
		GameSceneRouter.go_to_track_book(get_tree(), active_track_key)


func es_corrida_completado() -> bool:
	return _current_run_completion_handled


func completar_corrida_actual() -> void:
	if _current_run_completion_handled:
		return

	var track_key := active_track_key
	var level_number := _numero_nivel_valido(track_key)
	if level_number <= 0:
		return

	_current_run_completion_handled = true
	_bloquear_completado_corrida()

	if _usa_flujo_mapa:
		_guardar_progreso_de_mapa()
		mostrar_continuacion()
		run_completed.emit()
		return

	# --- Flujo de racha (lineal, todo acá) ---
	# 1. Capturar racha previa para calcular el feedback post-partida
	var previous_streak: Dictionary = Global.obtener_estado_racha()

	# 2. Registrar progreso y actividad de racha
	Global.marcar_nivel_completado(track_key, level_number)
	Global.registrar_actividad_racha(
		"level_completed",
		{"track_key": track_key, "level_number": level_number}
	)

	# 3. Persistir todo a disco
	SaveManager.registrar_nivel_completado(track_key, level_number)

	# 4. Preparar el feedback de racha para mostrarlo al avanzar
	var updated_streak: Dictionary = Global.obtener_estado_racha()
	_pending_streak_feedback = GameStreakTrackerScript.build_feedback(
		previous_streak,
		updated_streak,
		true
	)

	_mostrar_completado_corrida_retroalimentacion()
	run_completed.emit()

func _mostrar_completado_corrida_retroalimentacion() -> void:
	var chapter_fijo := _actual_nivel_numero()
	while is_inside_tree() and es_corrida_completado() and _actual_nivel_numero() == chapter_fijo:
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
	if not es_corrida_completado():
		return
	if _usa_flujo_mapa:
		continuar_al_siguiente_nodo()
		return
	if bool(_pending_streak_feedback.get("should_show", false)):
		var pending_feedback: Dictionary = _pending_streak_feedback.duplicate(true)
		var continue_target: Dictionary = _construir_objetivo_continuar_posterior_finalizacion(pending_feedback)
		_pending_streak_feedback = {}
		GameSceneRouter.go_to_streak(
			get_tree(),
			"",
			pending_feedback,
			continue_target
		)
		return
	_ir_a_destino_posterior_finalizacion()


## --- Continuación desde mapa ---

func _crear_continuador() -> void:
	continuador = ContinueCountdownScene.instantiate()
	add_child(continuador)
	_ubicar_continuador()
	continuador.continuar_solicitado.connect(continuar_al_siguiente_nodo)
	continuador.ocultar()


func _ubicar_continuador() -> void:
	continuador.position = CONTINUADOR_POSICION_FLECHA_DERECHA


func _guardar_progreso_de_mapa() -> void:
	if _nodo_actual.is_empty():
		return
	Global.marcar_nodo_jugable_completado(active_track_key, _nodo_actual)


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

	if _nodo_actual.is_empty():
		_ir_a_destino_posterior_finalizacion()
		return

	Global.solicitar_continuar(_nodo_actual)
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_retorno)


## --- Guardado rápido ---

func _on_guardar_progreso_boton_presionado() -> void:
	if es_corrida_completado():
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
	var run_line: String = manager_level.obtener_actual_corrida_guardar_label()
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
	save_progress_button.icon = SAVE_ICON_OK if success else SAVE_ICON_IDLE


func _construir_objetivo_continuar_posterior_finalizacion(streak_feedback: Dictionary = {}) -> Dictionary:
	var continue_target: Dictionary
	if active_track_key == DEFAULT_TRACK_KEY:
		continue_target = {"type": "map"}
		_agregar_vista_previa_mock_racha(continue_target, streak_feedback)
		return continue_target

	var next_level: int = _actual_nivel_numero() + 1
	var level_count: int = Global.obtener_pista_nivel_cantidad(active_track_key)
	if next_level <= level_count:
		continue_target = {
			"type": "track_level",
			"track_key": active_track_key,
			"level_number": next_level
		}
		_agregar_vista_previa_mock_racha(continue_target, streak_feedback)
		return continue_target

	continue_target = {
		"type": "track_book",
		"track_key": active_track_key
	}
	_agregar_vista_previa_mock_racha(continue_target, streak_feedback)
	return continue_target


func _agregar_vista_previa_mock_racha(
	continue_target: Dictionary,
	streak_feedback: Dictionary = {}
) -> void:
	if not GameStreakDebugScript.is_preview_enabled():
		return
	var current_count: int = int(streak_feedback.get("current_count", 0))
	if current_count <= 0 or current_count >= GameStreakDebugScript.PREVIEW_MAX_COUNT:
		return
	var preview_counts: Array[int] = []
	for preview_count in range(
		current_count + 1,
		GameStreakDebugScript.PREVIEW_MAX_COUNT + 1
	):
		preview_counts.append(preview_count)
	if preview_counts.is_empty():
		return
	continue_target[GameStreakDebugScript.PREVIEW_COUNTS_KEY] = preview_counts


func _ir_a_destino_posterior_finalizacion() -> void:
	var continue_target: Dictionary = _construir_objetivo_continuar_posterior_finalizacion()
	match str(continue_target.get("type", "")).strip_edges():
		"map":
			GameSceneRouter.go_to_map(get_tree())
		"track_level":
			GameSceneRouter.go_to_track_level(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges(),
				int(continue_target.get("level_number", -1))
			)
		"track_book":
			GameSceneRouter.go_to_track_book(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges()
			)
		_:
			GameSceneRouter.go_to_mode_selector(get_tree())


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
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false


func _on_guardar_retroalimentacion_timeout() -> void:
	if not is_inside_tree():
		return
	_reiniciar_guardar_retroalimentacion_visual_estado()


func _bloquear_completado_corrida() -> void:
	Item_level.is_dragging = null
	_establecer_interacciones_jugabilidad_habilitadas(false)
	next_chapter_button.disabled = false
	teaching_sprite.show()
	_aplicar_finalizacion_visual_estado()


func _restaurar_estado_posterior_finalizacion() -> void:
	restaurar_finalizacion_visual_estado()
	_establecer_interacciones_jugabilidad_habilitadas(true)
	next_chapter_button.show()
	teaching_sprite.hide()
	if continuador != null:
		continuador.ocultar()


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
	if not grayscale_on_completion:
		return

	var grayscale_material := ShaderMaterial.new()
	grayscale_material.shader = COMPLETION_BLACK_AND_WHITE_SHADER
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
	
	
