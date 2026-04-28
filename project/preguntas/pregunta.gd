extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
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
	_collect_answer_buttons()
	_setup_from_active_session()
	if not _can_start_quiz():
		_show_blocking_content_error(_blocking_error_message)
		return
	_shuffle_quiz_questions()
	_load_current_question()


func _collect_answer_buttons() -> void:
	botones.clear()
	_answer_button_templates.clear()
	for raw_button in _answers_container.get_children():
		var boton_respuesta: Button = raw_button as Button
		if boton_respuesta == null:
			continue
		var template_button: Button = boton_respuesta.duplicate() as Button
		if template_button != null:
			_answer_button_templates.append(template_button)
		_register_answer_button(boton_respuesta)


func _register_answer_button(boton_respuesta: Button) -> void:
	botones.append(boton_respuesta)
	boton_respuesta.pressed.connect(_respuesta_boton.bind(boton_respuesta))


func _setup_from_active_session() -> void:
	_reset_map_session_context()
	_blocking_error_message = ""

	var session_context: Dictionary = Global.obtener_activo_pregunta_sesion()
	if session_context.is_empty():
		return

	var node_data: Dictionary = _read_session_node_data(session_context)
	if not node_data.is_empty():
		setup_from_node_data(node_data, session_context)
		return

	var legacy_theme: ThemePreg = _load_legacy_theme_from_session(session_context)
	if legacy_theme == null:
		_set_blocking_error_message(
			"No se pudo cargar el contenido del nodo. Revisa su JSON o el recurso fallback."
		)
		_apply_map_session_context(session_context)
		return

	quiz = legacy_theme
	_apply_map_session_context(session_context)


func setup_from_node_data(node_data: Dictionary, session_context: Dictionary) -> bool:
	# Entrada clara de la escena con node_data ya normalizado por NodeContentLoader.
	_apply_map_session_context(session_context)
	var quiz_result: Dictionary = QuestionJsonLoaderScript.cargar_resultado_desde_node_data(
		node_data,
		str(session_context.get("question_json_path", "")).strip_edges()
	)
	if not bool(quiz_result.get("ok", false)):
		_set_blocking_error_message(
			str(quiz_result.get("error", "No se pudo adaptar el nodo quiz_choice."))
		)
		return false

	quiz = quiz_result.get("theme") as ThemePreg
	return true


func _reset_map_session_context() -> void:
	_has_map_session = false
	_active_question_key = ""
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH


func _load_legacy_theme_from_session(session_context: Dictionary) -> ThemePreg:
	# Compatibilidad temporal con fallback legacy .tres.
	var question_resource: Preguntas = _load_legacy_question_from_session(session_context)
	if question_resource != null:
		return _construir_tema_con_una_pregunta(question_resource)
	return null


func _read_session_node_data(session_context: Dictionary) -> Dictionary:
	var raw_node_data: Variant = session_context.get("node_content", {})
	if raw_node_data is Dictionary:
		return (raw_node_data as Dictionary).duplicate(true)
	return {}


func _load_legacy_question_from_session(session_context: Dictionary) -> Preguntas:
	var question_resource_path := str(
		session_context.get("question_resource_path", "")
	).strip_edges()
	if question_resource_path.is_empty():
		push_warning("Preguntas: no hay question_resource_path para fallback .tres.")
		return null
	var question_resource: Variant = load(question_resource_path)
	if question_resource == null:
		push_warning(
			"Preguntas: no se pudo cargar la pregunta configurada para el mapa: %s"
			% question_resource_path
		)
		return null
	if not question_resource is Preguntas:
		push_warning(
			"Preguntas: el recurso configurado para el mapa no es una pregunta valida: %s"
			% question_resource_path
		)
		return null
	return question_resource as Preguntas


func _construir_tema_con_una_pregunta(question_resource: Preguntas) -> ThemePreg:
	var question_theme: ThemePreg = ThemePregScript.new()
	var typed_theme: Array[Preguntas] = []
	typed_theme.append(question_resource)
	question_theme.theme = typed_theme
	return question_theme


func _apply_map_session_context(session_context: Dictionary) -> void:
	track_key = str(session_context.get("track_key", track_key)).strip_edges()
	nivel_id = int(session_context.get("nivel_id", nivel_id))
	_active_question_key = str(session_context.get("question_key", "")).strip_edges()
	_return_scene_path = str(
		session_context.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = true


func _can_start_quiz() -> bool:
	if quiz == null:
		_set_blocking_error_message("No hay contenido cargado para este nodo.")
		return false
	if quiz.theme.is_empty():
		_set_blocking_error_message("El nodo no tiene preguntas jugables.")
		return false
	return true


func _question_count() -> int:
	return 0 if quiz == null else quiz.theme.size()


func _shuffle_quiz_questions() -> void:
	if _question_count() <= 1:
		return
	quiz.theme.shuffle()


func _load_current_question() -> void:
	bloqueado = false

	if quiz == null:
		_set_blocking_error_message("No hay quiz asignado para cargar.")
		_show_blocking_content_error(_blocking_error_message)
		return

	if indice_pregunta_actual >= _question_count():
		_game_over()
		return

	pregunta_label.text = pregunta_actual.info_pregunta
	_apply_question_media(pregunta_actual)
	_apply_answer_options(pregunta_actual.opciones)


func _apply_answer_options(opciones_actuales: Array[String]) -> void:
	_ensure_answer_button_count(opciones_actuales.size())
	for button_index in range(botones.size()):
		var boton_respuesta: Button = botones[button_index]
		if button_index >= opciones_actuales.size():
			_hide_answer_button(boton_respuesta)
			continue
		_configure_answer_button(boton_respuesta, opciones_actuales[button_index])


func _ensure_answer_button_count(required_count: int) -> void:
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
		_register_answer_button(new_button)


func _configure_answer_button(boton_respuesta: Button, answer_text: String) -> void:
	boton_respuesta.show()
	boton_respuesta.text = answer_text
	boton_respuesta.tooltip_text = answer_text
	boton_respuesta.set_meta("respuesta", answer_text)
	boton_respuesta.modulate = Color.WHITE
	boton_respuesta.disabled = false
	boton_respuesta.scale = Vector2.ONE
	boton_respuesta.rotation_degrees = 0


func _hide_answer_button(boton_respuesta: Button) -> void:
	boton_respuesta.hide()
	boton_respuesta.disabled = true
	boton_respuesta.tooltip_text = ""
	boton_respuesta.set_meta("respuesta", "")


func _apply_question_media(question_resource: Preguntas) -> void:
	_reset_question_media_view()
	if question_resource == null:
		return

	if question_resource.tipo != Enum.TipoPregunta.IMAGEN:
		return
	if question_resource.pregunta_imagen == null:
		return

	_visual_panel.show()
	_question_image.show()
	_question_image.texture = question_resource.pregunta_imagen


func _reset_question_media_view() -> void:
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null
	if _question_image != null:
		_question_image.texture = null
		_question_image.hide()
	if _visual_panel != null:
		_visual_panel.hide()


func _respuesta_boton(boton: Button) -> void:
	if bloqueado:
		return

	bloqueado = true
	_lock_answer_buttons()

	var respuesta_elegida: String = str(boton.get_meta("respuesta"))

	if pregunta_actual.correct == respuesta_elegida:
		_respuesta_correcta(boton)
		puntaje += 1
	else:
		_respuesta_incorrecta(boton)

	await get_tree().create_timer(1.2).timeout
	_advance_to_next_question()


func _lock_answer_buttons() -> void:
	for boton_respuesta in botones:
		boton_respuesta.disabled = true


func _respuesta_correcta(boton: Button) -> void:
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


func _respuesta_incorrecta(boton: Button) -> void:
	var tween = create_tween()

	boton.modulate = Color(1, 0, 0)

	for i in 5:
		tween.tween_property(boton, "rotation_degrees", 8, 0.03)
		tween.tween_property(boton, "rotation_degrees", -8, 0.03)

	tween.tween_property(boton, "rotation_degrees", 0, 0.05)


func _advance_to_next_question() -> void:
	indice_pregunta_actual += 1
	_load_current_question()


func _game_over() -> void:
	if _has_map_session and _question_count() <= 1:
		_finish_map_question_session()
		_return_to_map()
		return

	if _question_count() <= 1:
		_configure_game_over_panel(
			"",
			"Muy bien" if puntaje > 0 else "No era esa",
			false,
			true
		)
	else:
		_configure_game_over_panel("Aciertos:", str(puntaje, "/", _question_count()), true, true)

	if _has_map_session:
		_finish_map_question_session()
		return

	_finish_regular_question_session()


func _configure_game_over_panel(
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


func _show_blocking_content_error(message: String) -> void:
	bloqueado = true
	_lock_answer_buttons()
	_reset_question_media_view()
	for boton_respuesta in botones:
		_hide_answer_button(boton_respuesta)

	var safe_message: String = _acotar_mensaje(message)
	_configure_game_over_panel(
		"Contenido no disponible",
		safe_message,
		true,
		true,
		CONTENT_ERROR_TITLE_FONT_SIZE,
		CONTENT_ERROR_BODY_FONT_SIZE,
		true
	)


func _finish_map_question_session() -> void:
	_register_completed_map_question_if_needed()
	SaveManager.registrar_sesion_preguntas_completada(_question_count(), puntaje)


func _finish_regular_question_session() -> void:
	Global.marcar_nivel_completado(track_key, nivel_id)
	SaveManager.registrar_nivel_completado(track_key, nivel_id)


func _register_completed_map_question_if_needed() -> void:
	if _has_map_session and not _active_question_key.is_empty():
		Global.marcar_pregunta_completado(track_key, _active_question_key)


func _set_blocking_error_message(message: String) -> void:
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
	_return_to_map()


func _on_atrás_pressed() -> void:
	_return_to_map()


func _return_to_map() -> void:
	_reset_question_media_view()
	Global.limpiar_activo_pregunta_sesion()
	get_tree().change_scene_to_file(_return_scene_path)
