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

var _active_node_key: String = ""
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
	if _cantidad_de_preguntas() > 1:
		quiz.theme.shuffle()
	_renderizar_pregunta()


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
	boton_respuesta.pressed.connect(_responder.bind(boton_respuesta))

func _configurar_desde_sesion_activa() -> void:
	_reiniciar_contexto_sesion()
	_blocking_error_message = ""

	var contexto_sesion: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	if contexto_sesion.is_empty():
		return

	_aplicar_contexto_sesion(contexto_sesion)
	var resultado_quiz: Dictionary = QuestionJsonLoaderScript.cargar_tema_desde_sesion(contexto_sesion)
	if not bool(resultado_quiz.get("ok", false)):
		_establecer_mensaje_de_error(
			str(resultado_quiz.get("error", "No se pudo cargar el contenido del nodo."))
		)
		return
	quiz = resultado_quiz.get("data", {}).get("theme") as ThemePreg


func _reiniciar_contexto_sesion() -> void:
	_has_map_session = false
	_active_node_key = ""
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH

func configurar_desde_datos_nodo(datos_nodo: Dictionary, contexto_sesion: Dictionary) -> bool:
	_aplicar_contexto_sesion(contexto_sesion)
	var ruta_json: String = str(contexto_sesion.get("node_json_path", "")).strip_edges()
	var quiz_result: Dictionary = QuestionJsonLoaderScript.cargar_resultado_desde_datos_nodo(
		datos_nodo,
		ruta_json
	)
	if not bool(quiz_result.get("ok", false)):
		_establecer_mensaje_de_error(
			str(quiz_result.get("error", "No se pudo adaptar el nodo quiz_choice."))
		)
		return false

	quiz = quiz_result.get("data", {}).get("theme") as ThemePreg
	return true


func _aplicar_contexto_sesion(session_context: Dictionary) -> void:
	track_key = str(session_context.get("track_key", track_key)).strip_edges()
	nivel_id = int(session_context.get("nivel_id", nivel_id))
	_active_node_key = str(session_context.get("node_key", "")).strip_edges()
	_return_scene_path = str(
		session_context.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = not session_context.is_empty()

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

func _renderizar_pregunta() -> void:
	bloqueado = false

	if quiz == null:
		_establecer_mensaje_de_error("No hay quiz asignado para cargar.")
		_mostrar_error_bloqueante(_blocking_error_message)
		return

	if indice_pregunta_actual >= _cantidad_de_preguntas():
		_finalizar_quiz()
		return

	pregunta_label.text = pregunta_actual.info_pregunta
	_renderizar_media_de_pregunta(pregunta_actual)
	_renderizar_opciones(pregunta_actual.opciones)

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

func _renderizar_media_de_pregunta(pregunta_recurso: Preguntas) -> void:
	_limpiar_media_de_pregunta()
	if pregunta_recurso == null:
		return

	if pregunta_recurso.tipo != Enum.TipoPregunta.IMAGEN:
		return
	if pregunta_recurso.pregunta_imagen == null:
		return

	_visual_panel.show()
	_question_image.show()
	_question_image.texture = pregunta_recurso.pregunta_imagen

func _limpiar_media_de_pregunta() -> void:
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null
	if _question_image != null:
		_question_image.texture = null
		_question_image.hide()
	if _visual_panel != null:
		_visual_panel.hide()

func _responder(boton: Button) -> void:
	if bloqueado:
		return

	bloqueado = true
	for boton_respuesta in botones:
		boton_respuesta.disabled = true

	var respuesta_elegida: String = str(boton.get_meta("respuesta"))
	var es_correcta: bool = pregunta_actual.correct == respuesta_elegida
	if es_correcta:
		puntaje += 1

	_mostrar_feedback_respuesta(boton, es_correcta)

	await get_tree().create_timer(1.2).timeout
	indice_pregunta_actual += 1
	_renderizar_pregunta()

func _mostrar_feedback_respuesta(boton: Button, es_correcta: bool) -> void:
	var tween = create_tween()
	if es_correcta and _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = CORRECT_ANSWER_SOUND
		_audio_player.play()

	if es_correcta:
		boton.modulate = Color(0, 1, 0)
		tween.tween_property(boton, "scale", Vector2(1.2, 0.8), 0.08)
		tween.tween_property(boton, "scale", Vector2(0.9, 1.1), 0.08)
		tween.tween_property(boton, "scale", Vector2(1.05, 0.95), 0.08)
		tween.tween_property(boton, "scale", Vector2(1, 1), 0.1)
		return

	boton.modulate = Color(1, 0, 0)
	for unused_index in 5:
		tween.tween_property(boton, "rotation_degrees", 8, 0.03)
		tween.tween_property(boton, "rotation_degrees", -8, 0.03)
	tween.tween_property(boton, "rotation_degrees", 0, 0.05)

func _finalizar_quiz() -> void:
	if _has_map_session and _cantidad_de_preguntas() <= 1:
		if not _active_node_key.is_empty():
			Global.marcar_nodo_jugable_completado(track_key, _active_node_key)
		SaveManager.registrar_sesion_preguntas_completada(_cantidad_de_preguntas(), puntaje)
		_volver_al_mapa()
		return

	if _cantidad_de_preguntas() <= 1:
		_configurar_panel_final("", "Muy bien" if puntaje > 0 else "No era esa", false, true)
	else:
		_configurar_panel_final("Aciertos:", str(puntaje, "/", _cantidad_de_preguntas()), true, true)

	if _has_map_session:
		if not _active_node_key.is_empty():
			Global.marcar_nodo_jugable_completado(track_key, _active_node_key)
		SaveManager.registrar_sesion_preguntas_completada(_cantidad_de_preguntas(), puntaje)
		return

	Global.marcar_nivel_completado(track_key, nivel_id)
	SaveManager.registrar_nivel_completado(track_key, nivel_id)

func _configurar_panel_final(
	texto_titulo: String,
	texto_puntaje: String,
	titulo_visible: bool,
	puntaje_visible: bool,
	tamano_titulo: int = GAME_OVER_DEFAULT_FONT_SIZE,
	tamano_puntaje: int = GAME_OVER_DEFAULT_FONT_SIZE,
	wrap_score: bool = false
) -> void:
	_game_over_panel.show()
	_game_over_title.visible = titulo_visible
	_game_over_score.visible = puntaje_visible
	_game_over_title.text = texto_titulo
	_game_over_score.text = texto_puntaje
	_game_over_title.add_theme_font_size_override("font_size", tamano_titulo)
	_game_over_score.add_theme_font_size_override("font_size", tamano_puntaje)
	_game_over_score.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
		if wrap_score
		else TextServer.AUTOWRAP_OFF
	)

func _mostrar_error_bloqueante(mensaje: String) -> void:
	bloqueado = true
	for boton_respuesta in botones:
		boton_respuesta.disabled = true
	_limpiar_media_de_pregunta()
	for boton_respuesta in botones:
		_ocultar_boton_respuesta(boton_respuesta)

	var mensaje_limpio: String = mensaje.replace("\n", " ").strip_edges()
	if mensaje_limpio.is_empty():
		mensaje_limpio = "Revisa el archivo JSON del nodo."
	elif mensaje_limpio.length() > 140:
		mensaje_limpio = "%s..." % mensaje_limpio.substr(0, 137)
	_configurar_panel_final(
		"Contenido no disponible",
		mensaje_limpio,
		true,
		true,
		CONTENT_ERROR_TITLE_FONT_SIZE,
		CONTENT_ERROR_BODY_FONT_SIZE,
		true
	)

func _establecer_mensaje_de_error(mensaje: String) -> void:
	var mensaje_limpio: String = mensaje.strip_edges()
	if mensaje_limpio.is_empty():
		return
	if not _blocking_error_message.is_empty():
		return
	_blocking_error_message = mensaje_limpio

func _on_jugar_nuevamente_pressed() -> void:
	_volver_al_mapa()

func _on_atrás_pressed() -> void:
	_volver_al_mapa()

func _volver_al_mapa() -> void:
	_limpiar_media_de_pregunta()
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_return_scene_path)
