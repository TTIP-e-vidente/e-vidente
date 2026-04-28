extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const QuestionJsonLoaderScript := preload("res://preguntas/QuestionJsonLoader.gd")
const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH
const CORRECT_ANSWER_SOUND := preload("res://assets-sistema/sonidos/bonus-points-190035.mp3")

const GAME_OVER_DEFAULT_FONT_SIZE := 81
const CONTENT_ERROR_TITLE_FONT_SIZE := 42
const CONTENT_ERROR_BODY_FONT_SIZE := 26

@export var quiz: ThemePreg
@export var nivel_id: int = 2
@export var track_key: String = "celiaquia"

var botones: Array[Button] = []
var indice_pregunta_actual: int = 0
var puntaje: int = 0
var bloqueado: bool = false

var _active_question_key: String = ""
var _has_map_session: bool = false
var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH
var _blocking_error_message: String = ""
var _answer_button_templates: Array[Button] = []

var pregunta_actual: Preguntas:
	get : return quiz.theme[indice_pregunta_actual]

@onready var pregunta_label: Label = $Contenido/Informacion/Pregunta
@onready var _visual_panel: Panel = $Contenido/Informacion/Visual
@onready var _question_image: TextureRect = $Contenido/Informacion/Visual/Imagen
@onready var _answers_container: VBoxContainer = $Contenido/Preguntas
@onready var _audio_player: AudioStreamPlayer2D = $Contenido/Audio
@onready var _game_over_panel: ColorRect = $Contenido/GameOver
@onready var _game_over_title: Label = $Contenido/GameOver/Aciertos
@onready var _game_over_score: Label = $Contenido/GameOver/Puntaje


func _ready() -> void:
	puntaje = 0
	_recolectar_botones_respuesta()
	_configurar_desde_sesion_activa()
	if not _puede_iniciar_quiz():
		_mostrar_error_bloqueante(_blocking_error_message)
		return
	_mezclar_preguntas_del_quiz()
	_renderizar_pregunta_actual()


func _recolectar_botones_respuesta() -> void:
	botones.clear()
	_answer_button_templates.clear()
	for raw_button in _answers_container.get_children():
		var boton_respuesta: Button = raw_button as Button
		if boton_respuesta == null:
			continue
		var template_button: Button = boton_respuesta.duplicate() as Button
		if template_button != null:
			_answer_button_templates.append(template_button)
		_registrar_boton_respuesta(boton_respuesta)


func _registrar_boton_respuesta(boton_respuesta: Button) -> void:
	botones.append(boton_respuesta)
	boton_respuesta.pressed.connect(_al_seleccionar_respuesta.bind(boton_respuesta))


func _configurar_desde_sesion_activa() -> void:
	_reiniciar_contexto_de_mapa()
	_blocking_error_message = ""

	var session_context: Dictionary = Global.obtener_activo_pregunta_sesion()
	if session_context.is_empty():
		return

	var datos_nodo: Dictionary = _leer_datos_nodo_de_sesion(session_context)
	if not datos_nodo.is_empty():
		configurar_desde_datos_nodo(datos_nodo, session_context)
		return

	var load_result: Dictionary = QuestionJsonLoaderScript.cargar_tema_desde_sesion(session_context)
	_aplicar_contexto_de_mapa(session_context)
	if not bool(load_result.get("ok", false)):
		_establecer_mensaje_de_error(
			str(load_result.get("error", "No se pudo cargar el contenido del nodo."))
		)
		return
	quiz = load_result.get("theme") as ThemePreg


func configurar_desde_datos_nodo(datos_nodo: Dictionary, session_context: Dictionary) -> bool:
	# Desde aca la escena trabaja solo con el formato oficial despues del loader.
	_aplicar_contexto_de_mapa(session_context)
	var quiz_result: Dictionary = QuestionJsonLoaderScript.cargar_resultado_desde_datos_nodo(
		datos_nodo,
		str(session_context.get("question_json_path", "")).strip_edges()
	)
	if not bool(quiz_result.get("ok", false)):
		_establecer_mensaje_de_error(
			str(quiz_result.get("error", "No se pudo adaptar el nodo quiz_choice."))
		)
		return false

	quiz = quiz_result.get("theme") as ThemePreg
	return true


func _reiniciar_contexto_de_mapa() -> void:
	_has_map_session = false
	_active_question_key = ""
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH


func _leer_datos_nodo_de_sesion(session_context: Dictionary) -> Dictionary:
	var raw_node_data: Variant = session_context.get("node_content", {})
	if raw_node_data is Dictionary:
		return (raw_node_data as Dictionary).duplicate(true)
	return {}


func _aplicar_contexto_de_mapa(session_context: Dictionary) -> void:
	track_key = str(session_context.get("track_key", track_key)).strip_edges()
	nivel_id = int(session_context.get("nivel_id", nivel_id))
	_active_question_key = str(session_context.get("question_key", "")).strip_edges()
	_return_scene_path = str(
		session_context.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = true


func _puede_iniciar_quiz() -> bool:
	if quiz == null:
		_establecer_mensaje_de_error("No hay contenido cargado para este nodo.")
		return false
	if quiz.theme.is_empty():
		_establecer_mensaje_de_error("El nodo no tiene preguntas jugables.")
		return false
	return true


func _cantidad_de_preguntas() -> int:
	return 0 if quiz == null else quiz.theme.size()


func _mezclar_preguntas_del_quiz() -> void:
	if _cantidad_de_preguntas() <= 1:
		return
	quiz.theme.shuffle()


func _renderizar_pregunta_actual() -> void:
	bloqueado = false

	if quiz == null:
		_establecer_mensaje_de_error("No hay quiz asignado para cargar.")
		_mostrar_error_bloqueante(_blocking_error_message)
		return

	if indice_pregunta_actual >= _cantidad_de_preguntas():
		_finalizar_quiz()
		return

	_renderizar_encabezado_pregunta()
	_renderizar_opciones(pregunta_actual.opciones)


func _renderizar_encabezado_pregunta() -> void:
	pregunta_label.text = pregunta_actual.info_pregunta
	_renderizar_media_de_pregunta(pregunta_actual)


func _renderizar_opciones(opciones_actuales: Array[String]) -> void:
	_asegurar_cantidad_de_botones(opciones_actuales.size())
	for button_index in range(botones.size()):
		var boton_respuesta: Button = botones[button_index]
		if button_index >= opciones_actuales.size():
			_ocultar_boton_respuesta(boton_respuesta)
			continue
		_configurar_boton_respuesta(boton_respuesta, opciones_actuales[button_index])


func _asegurar_cantidad_de_botones(required_count: int) -> void:
	if required_count <= botones.size():
		return
	if _answer_button_templates.is_empty():
		return

	while botones.size() < required_count:
		var template_index: int = botones.size() % _answer_button_templates.size()
		var template_button: Button = _answer_button_templates[template_index]
		var new_button: Button = template_button.duplicate() as Button
		if new_button == null:
			return
		new_button.name = "Boton%d" % (botones.size() + 1)
		_answers_container.add_child(new_button)
		_registrar_boton_respuesta(new_button)


func _configurar_boton_respuesta(boton_respuesta: Button, answer_text: String) -> void:
	boton_respuesta.show()
	boton_respuesta.text = answer_text
	boton_respuesta.tooltip_text = answer_text
	boton_respuesta.set_meta("respuesta", answer_text)
	boton_respuesta.modulate = Color.WHITE
	boton_respuesta.disabled = false
	boton_respuesta.scale = Vector2.ONE
	boton_respuesta.rotation_degrees = 0


func _ocultar_boton_respuesta(boton_respuesta: Button) -> void:
	boton_respuesta.hide()
	boton_respuesta.disabled = true
	boton_respuesta.tooltip_text = ""
	boton_respuesta.set_meta("respuesta", "")


func _renderizar_media_de_pregunta(question_resource: Preguntas) -> void:
	_limpiar_media_de_pregunta()
	if question_resource == null:
		return

	if question_resource.tipo != Enum.TipoPregunta.IMAGEN:
		return
	if question_resource.pregunta_imagen == null:
		return

	_visual_panel.show()
	_question_image.show()
	_question_image.texture = question_resource.pregunta_imagen


func _limpiar_media_de_pregunta() -> void:
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null
	if _question_image != null:
		_question_image.texture = null
		_question_image.hide()
	if _visual_panel != null:
		_visual_panel.hide()


func _al_seleccionar_respuesta(boton: Button) -> void:
	if bloqueado:
		return

	bloqueado = true
	_bloquear_botones_de_respuesta()

	var respuesta_elegida: String = str(boton.get_meta("respuesta"))

	if pregunta_actual.correct == respuesta_elegida:
		_mostrar_feedback_acierto(boton)
		puntaje += 1
	else:
		_mostrar_feedback_error(boton)

	await get_tree().create_timer(1.2).timeout
	_avanzar_a_la_siguiente_pregunta()


func _bloquear_botones_de_respuesta() -> void:
	for boton_respuesta in botones:
		boton_respuesta.disabled = true


func _mostrar_feedback_acierto(boton: Button) -> void:
	var tween = create_tween()
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = CORRECT_ANSWER_SOUND
		_audio_player.play()

	boton.modulate = Color(0, 1, 0)

	tween.tween_property(boton, "scale", Vector2(1.2, 0.8), 0.08)
	tween.tween_property(boton, "scale", Vector2(0.9, 1.1), 0.08)
	tween.tween_property(boton, "scale", Vector2(1.05, 0.95), 0.08)
	tween.tween_property(boton, "scale", Vector2(1, 1), 0.1)


func _mostrar_feedback_error(boton: Button) -> void:
	var tween = create_tween()

	boton.modulate = Color(1, 0, 0)

	for i in 5:
		tween.tween_property(boton, "rotation_degrees", 8, 0.03)
		tween.tween_property(boton, "rotation_degrees", -8, 0.03)

	tween.tween_property(boton, "rotation_degrees", 0, 0.05)


func _avanzar_a_la_siguiente_pregunta() -> void:
	indice_pregunta_actual += 1
	_renderizar_pregunta_actual()


func _finalizar_quiz() -> void:
	if _has_map_session and _cantidad_de_preguntas() <= 1:
		_finalizar_sesion_del_mapa()
		_finalizar_actividad_y_volver()
		return

	if _cantidad_de_preguntas() <= 1:
		_configurar_panel_final(
			"",
			"Muy bien" if puntaje > 0 else "No era esa",
			false,
			true
		)
	else:
		_configurar_panel_final("Aciertos:", str(puntaje, "/", _cantidad_de_preguntas()), true, true)

	if _has_map_session:
		_finalizar_sesion_del_mapa()
		return

	_finalizar_sesion_regular()


func _configurar_panel_final(
	title_text: String,
	score_text: String,
	title_visible: bool,
	score_visible: bool,
	title_font_size: int = GAME_OVER_DEFAULT_FONT_SIZE,
	score_font_size: int = GAME_OVER_DEFAULT_FONT_SIZE,
	wrap_score: bool = false
) -> void:
	_game_over_panel.show()
	_game_over_title.visible = title_visible
	_game_over_score.visible = score_visible
	_game_over_title.text = title_text
	_game_over_score.text = score_text
	_game_over_title.add_theme_font_size_override("font_size", title_font_size)
	_game_over_score.add_theme_font_size_override("font_size", score_font_size)
	_game_over_score.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
		if wrap_score
		else TextServer.AUTOWRAP_OFF
	)


func _mostrar_error_bloqueante(message: String) -> void:
	bloqueado = true
	_bloquear_botones_de_respuesta()
	_limpiar_media_de_pregunta()
	for boton_respuesta in botones:
		_ocultar_boton_respuesta(boton_respuesta)

	var safe_message: String = _acotar_mensaje(message)
	_configurar_panel_final(
		"Contenido no disponible",
		safe_message,
		true,
		true,
		CONTENT_ERROR_TITLE_FONT_SIZE,
		CONTENT_ERROR_BODY_FONT_SIZE,
		true
	)


func _finalizar_sesion_del_mapa() -> void:
	_registrar_pregunta_completada_si_corresponde()
	SaveManager.registrar_sesion_preguntas_completada(_cantidad_de_preguntas(), puntaje)


func _finalizar_sesion_regular() -> void:
	Global.marcar_nivel_completado(track_key, nivel_id)
	SaveManager.registrar_nivel_completado(track_key, nivel_id)


func _registrar_pregunta_completada_si_corresponde() -> void:
	if _has_map_session and not _active_question_key.is_empty():
		Global.marcar_pregunta_completado(track_key, _active_question_key)


func _establecer_mensaje_de_error(message: String) -> void:
	var clean_message: String = message.strip_edges()
	if clean_message.is_empty():
		return
	if not _blocking_error_message.is_empty():
		return
	_blocking_error_message = clean_message


func _acotar_mensaje(message: String) -> String:
	var clean_message: String = message.replace("\n", " ").strip_edges()
	if clean_message.is_empty():
		return "Revisa el archivo JSON del nodo."
	if clean_message.length() <= 140:
		return clean_message
	return "%s..." % clean_message.substr(0, 137)


func _on_jugar_nuevamente_pressed() -> void:
	_finalizar_actividad_y_volver()


func _on_atrás_pressed() -> void:
	_finalizar_actividad_y_volver()


func _finalizar_actividad_y_volver() -> void:
	_limpiar_media_de_pregunta()
	Global.limpiar_activo_pregunta_sesion()
	get_tree().change_scene_to_file(_return_scene_path)
