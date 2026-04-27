extends Node

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ThemePregScript := preload("res://preguntas/theme/theme.gd")
const DEFAULT_RETURN_SCENE_PATH := GameSceneRouter.MAP_SCENE_PATH
const CORRECT_ANSWER_SOUND := preload("res://assets-sistema/sonidos/bonus-points-190035.mp3")

@export var quiz: ThemePreg
@export var nivel_id: int = 2
@export var track_key: String = "celiaquia"

var botones: Array[Button] = []
var index: int = 0
var puntaje: int = 0
var bloqueado: bool = false

var _max_questions: int = 0
var _active_question_key: String = ""
var _has_map_session: bool = false
var _return_scene_path: String = DEFAULT_RETURN_SCENE_PATH

var pregunta_actual: Preguntas:
	get : return quiz.theme[index]

@onready var preguntas: Label = $Contenido/Informacion/Pregunta
@onready var _audio_player: AudioStreamPlayer2D = $Contenido/Audio
@onready var _game_over_panel: ColorRect = $Contenido/GameOver
@onready var _game_over_title: Label = $Contenido/GameOver/Aciertos
@onready var _game_over_score: Label = $Contenido/GameOver/Puntaje

func _ready() -> void:
	_prepare_question_session()
	_sync_question_count()
	puntaje = 0
	if _audio_player != null:
		_audio_player.stream = CORRECT_ANSWER_SOUND
	_collect_answer_buttons()
	_shuffle_quiz_questions()
	_load_current_question()


func _collect_answer_buttons() -> void:
	botones.clear()
	for raw_button in $Contenido/Preguntas.get_children():
		var boton_respuesta: Button = raw_button as Button
		if boton_respuesta == null:
			continue
		botones.append(boton_respuesta)
		boton_respuesta.pressed.connect(_respuesta_boton.bind(boton_respuesta))


func _prepare_question_session() -> void:
	# Si la escena se abrio desde el mapa, reemplazamos el tema por una sola pregunta.
	_reset_map_question_session_state()

	var session_state: Dictionary = Global.obtener_activo_pregunta_sesion()
	if session_state.is_empty():
		return

	var question_resource: Preguntas = _load_question_from_map_session(session_state)
	if question_resource == null:
		return

	quiz = _build_single_question_theme(question_resource)
	_apply_map_session_context(session_state)


func _reset_map_question_session_state() -> void:
	_has_map_session = false
	_active_question_key = ""
	_return_scene_path = DEFAULT_RETURN_SCENE_PATH


func _load_question_from_map_session(session_state: Dictionary) -> Preguntas:
	var question_resource_path := str(
		session_state.get("question_resource_path", "")
	).strip_edges()
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


func _build_single_question_theme(question_resource: Preguntas) -> ThemePreg:
	var question_theme: ThemePreg = ThemePregScript.new()
	var typed_theme: Array[Preguntas] = []
	typed_theme.append(question_resource)
	question_theme.theme = typed_theme
	return question_theme


func _apply_map_session_context(session_state: Dictionary) -> void:
	track_key = str(session_state.get("track_key", track_key)).strip_edges()
	nivel_id = int(session_state.get("nivel_id", nivel_id))
	_active_question_key = str(session_state.get("question_key", "")).strip_edges()
	_return_scene_path = str(
		session_state.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _return_scene_path.is_empty():
		_return_scene_path = DEFAULT_RETURN_SCENE_PATH
	_has_map_session = true


func _sync_question_count() -> void:
	if quiz == null:
		_max_questions = 0
		return

	_max_questions = quiz.theme.size()


func _shuffle_quiz_questions() -> void:
	if quiz == null:
		return
	quiz.theme.shuffle()


func _load_current_question() -> void:
	bloqueado = false

	if quiz == null:
		push_warning("Preguntas: no hay quiz asignado para cargar.")
		return

	if index >= _max_questions or index >= quiz.theme.size():
		_game_over()
		return

	preguntas.text = pregunta_actual.info_pregunta

	var opciones_actuales: Array[String] = pregunta_actual.opciones
	_apply_answer_options(opciones_actuales)


func _apply_answer_options(opciones_actuales: Array[String]) -> void:
	for button_index in range(botones.size()):
		var boton_respuesta: Button = botones[button_index]
		if button_index >= opciones_actuales.size():
			_hide_answer_button(boton_respuesta)
			continue
		_configure_answer_button(boton_respuesta, opciones_actuales[button_index])


func _configure_answer_button(boton_respuesta: Button, answer_text: String) -> void:
	boton_respuesta.show()
	boton_respuesta.text = answer_text
	boton_respuesta.set_meta("respuesta", answer_text)
	boton_respuesta.modulate = Color.WHITE
	boton_respuesta.disabled = false
	boton_respuesta.scale = Vector2.ONE
	boton_respuesta.rotation_degrees = 0


func _hide_answer_button(boton_respuesta: Button) -> void:
	boton_respuesta.hide()
	boton_respuesta.disabled = true


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
	if _audio_player != null and _audio_player.stream != null:
		_audio_player.stop()
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
	index += 1
	_load_current_question()


func _game_over() -> void:
	if _has_map_session and _max_questions <= 1:
		_finish_map_question_session()
		_return_to_origin_scene()
		return

	_game_over_panel.show()
	if _max_questions <= 1:
		_game_over_title.visible = false
		_game_over_score.visible = true
		_game_over_score.text = "Muy bien" if puntaje > 0 else "No era esa"
	else:
		_game_over_title.visible = true
		_game_over_score.visible = true
		_game_over_title.text = "Aciertos:"
		_game_over_score.text = str(puntaje, "/", _max_questions)

	if _has_map_session:
		_finish_map_question_session()
		return

	_finish_regular_question_session()


func _finish_map_question_session() -> void:
	_register_completed_map_question_if_needed()
	SaveManager.record_question_session_completed(_max_questions, puntaje)


func _finish_regular_question_session() -> void:
	Global.marcar_nivel_completado(track_key, nivel_id)
	SaveManager.record_level_completed(track_key, nivel_id)


func _register_completed_map_question_if_needed() -> void:
	if _has_map_session and not _active_question_key.is_empty():
		Global.marcar_pregunta_completado(track_key, _active_question_key)


func _on_jugar_nuevamente_pressed() -> void:
	_return_to_origin_scene()


func _on_atrás_pressed() -> void:
	_return_to_origin_scene()


func _return_to_origin_scene() -> void:
	Global.limpiar_activo_pregunta_sesion()
	get_tree().change_scene_to_file(_return_scene_path)
