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

var _clave_nodo_activo: String = ""
var _tiene_sesion_de_mapa: bool = false
var _ruta_escena_de_retorno: String = DEFAULT_RETURN_SCENE_PATH
var _mensaje_error_bloqueante: String = ""
var _plantillas_botones_respuesta: Array[Button] = []

var pregunta_actual: Preguntas:
	get : return quiz.theme[indice_pregunta_actual]

@onready var pregunta_label: Label = $Contenido/Informacion/Pregunta
@onready var _visual_panel: Panel = $Contenido/Informacion/Visual
@onready var _imagen_pregunta: TextureRect = $Contenido/Informacion/Visual/Imagen
@onready var _contenedor_respuestas: VBoxContainer = $Contenido/Preguntas
@onready var _audio_player: AudioStreamPlayer2D = $Contenido/Audio
@onready var _panel_final: ColorRect = $Contenido/GameOver
@onready var _titulo_panel_final: Label = $Contenido/GameOver/Aciertos
@onready var _puntaje_panel_final: Label = $Contenido/GameOver/Puntaje

func _ready() -> void:
	puntaje = 0
	_recolectar_botones_respuesta()
	configurar_quiz_desde_sesion()
	if not _puede_iniciar_quiz():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	if _cantidad_de_preguntas() > 1:
		quiz.theme.shuffle()
	mostrar_pregunta()


func _recolectar_botones_respuesta() -> void:
	botones.clear()
	_plantillas_botones_respuesta.clear()
	for boton_crudo in _contenedor_respuestas.get_children():
		var boton_respuesta: Button = boton_crudo as Button
		if boton_respuesta == null:
			continue
		var boton_plantilla: Button = boton_respuesta.duplicate() as Button
		if boton_plantilla != null:
			_plantillas_botones_respuesta.append(boton_plantilla)
		_registrar_boton_respuesta(boton_respuesta)


func _registrar_boton_respuesta(boton_respuesta: Button) -> void:
	botones.append(boton_respuesta)
	boton_respuesta.pressed.connect(manejar_respuesta.bind(boton_respuesta))

func configurar_quiz_desde_sesion() -> void:
	_reiniciar_sesion_nodo()
	_mensaje_error_bloqueante = ""

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


func _reiniciar_sesion_nodo() -> void:
	_tiene_sesion_de_mapa = false
	_clave_nodo_activo = ""
	_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE_PATH

func configurar_desde_datos_nodo(datos_nodo: Dictionary, contexto_sesion: Dictionary) -> bool:
	_aplicar_contexto_sesion(contexto_sesion)
	var ruta_json: String = str(contexto_sesion.get("node_json_path", "")).strip_edges()
	var resultado_quiz: Dictionary = QuestionJsonLoaderScript.cargar_resultado_desde_datos_nodo(
		datos_nodo,
		ruta_json
	)
	if not bool(resultado_quiz.get("ok", false)):
		_establecer_mensaje_de_error(
			str(resultado_quiz.get("error", "No se pudo adaptar el nodo quiz_choice."))
		)
		return false

	quiz = resultado_quiz.get("data", {}).get("theme") as ThemePreg
	return true


func _aplicar_contexto_sesion(contexto_sesion: Dictionary) -> void:
	track_key = str(contexto_sesion.get("track_key", track_key)).strip_edges()
	nivel_id = int(contexto_sesion.get("nivel_id", nivel_id))
	_clave_nodo_activo = str(contexto_sesion.get("node_key", "")).strip_edges()
	_ruta_escena_de_retorno = str(
		contexto_sesion.get("return_scene_path", DEFAULT_RETURN_SCENE_PATH)
	).strip_edges()
	if _ruta_escena_de_retorno.is_empty():
		_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE_PATH
	_tiene_sesion_de_mapa = not contexto_sesion.is_empty()

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

func mostrar_pregunta() -> void:
	bloqueado = false

	if quiz == null:
		_establecer_mensaje_de_error("No hay quiz asignado para cargar.")
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return

	if indice_pregunta_actual >= _cantidad_de_preguntas():
		_finalizar_quiz()
		return

	pregunta_label.text = pregunta_actual.info_pregunta
	_mostrar_visual_de_pregunta(pregunta_actual)
	_mostrar_opciones(pregunta_actual.opciones)

func _mostrar_opciones(opciones_actuales: Array[String]) -> void:
	_asegurar_cantidad_de_botones(opciones_actuales.size())
	for indice_boton in range(botones.size()):
		var boton_respuesta: Button = botones[indice_boton]
		if indice_boton >= opciones_actuales.size():
			_ocultar_boton_respuesta(boton_respuesta)
			continue
		_configurar_boton_respuesta(boton_respuesta, opciones_actuales[indice_boton])

func _asegurar_cantidad_de_botones(cantidad_necesaria: int) -> void:
	if cantidad_necesaria <= botones.size():
		return
	if _plantillas_botones_respuesta.is_empty():
		return

	while botones.size() < cantidad_necesaria:
		var indice_plantilla: int = botones.size() % _plantillas_botones_respuesta.size()
		var boton_plantilla: Button = _plantillas_botones_respuesta[indice_plantilla]
		var nuevo_boton: Button = boton_plantilla.duplicate() as Button
		if nuevo_boton == null:
			return
		nuevo_boton.name = "Boton%d" % (botones.size() + 1)
		_contenedor_respuestas.add_child(nuevo_boton)
		_registrar_boton_respuesta(nuevo_boton)

func _configurar_boton_respuesta(boton_respuesta: Button, texto_respuesta: String) -> void:
	boton_respuesta.show()
	boton_respuesta.text = texto_respuesta
	boton_respuesta.tooltip_text = texto_respuesta
	boton_respuesta.set_meta("respuesta", texto_respuesta)
	boton_respuesta.modulate = Color.WHITE
	boton_respuesta.disabled = false
	boton_respuesta.scale = Vector2.ONE
	boton_respuesta.rotation_degrees = 0

func _ocultar_boton_respuesta(boton_respuesta: Button) -> void:
	boton_respuesta.hide()
	boton_respuesta.disabled = true
	boton_respuesta.tooltip_text = ""
	boton_respuesta.set_meta("respuesta", "")

func _mostrar_visual_de_pregunta(pregunta_recurso: Preguntas) -> void:
	_limpiar_media_de_pregunta()
	if pregunta_recurso == null:
		return

	if pregunta_recurso.tipo != Enum.TipoPregunta.IMAGEN:
		return
	if pregunta_recurso.pregunta_imagen == null:
		return

	_visual_panel.show()
	_imagen_pregunta.show()
	_imagen_pregunta.texture = pregunta_recurso.pregunta_imagen

func _limpiar_media_de_pregunta() -> void:
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null
	if _imagen_pregunta != null:
		_imagen_pregunta.texture = null
		_imagen_pregunta.hide()
	if _visual_panel != null:
		_visual_panel.hide()

func manejar_respuesta(boton: Button) -> void:
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
	mostrar_pregunta()

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
	var cantidad_preguntas: int = _cantidad_de_preguntas()
	if _tiene_sesion_de_mapa and cantidad_preguntas <= 1:
		_guardar_progreso_de_mapa(cantidad_preguntas)
		volver_al_mapa()
		return

	_mostrar_panel_final_del_quiz(cantidad_preguntas)

	if _tiene_sesion_de_mapa:
		_guardar_progreso_de_mapa(cantidad_preguntas)
		return

	Global.marcar_nivel_completado(track_key, nivel_id)
	SaveManager.registrar_nivel_completado(track_key, nivel_id)


func _mostrar_panel_final_del_quiz(cantidad_preguntas: int) -> void:
	if cantidad_preguntas <= 1:
		_configurar_panel_final("", "Muy bien" if puntaje > 0 else "No era esa", false, true)
		return

	_configurar_panel_final("Aciertos:", str(puntaje, "/", cantidad_preguntas), true, true)


func _guardar_progreso_de_mapa(cantidad_preguntas: int) -> void:
	if not _clave_nodo_activo.is_empty():
		Global.marcar_nodo_jugable_completado(track_key, _clave_nodo_activo)
	SaveManager.registrar_sesion_preguntas_completada(cantidad_preguntas, puntaje)

func _configurar_panel_final(
	texto_titulo: String,
	texto_puntaje: String,
	titulo_visible: bool,
	puntaje_visible: bool,
	tamano_titulo: int = GAME_OVER_DEFAULT_FONT_SIZE,
	tamano_puntaje: int = GAME_OVER_DEFAULT_FONT_SIZE,
	wrap_score: bool = false
) -> void:
	_panel_final.show()
	_titulo_panel_final.visible = titulo_visible
	_puntaje_panel_final.visible = puntaje_visible
	_titulo_panel_final.text = texto_titulo
	_puntaje_panel_final.text = texto_puntaje
	_titulo_panel_final.add_theme_font_size_override("font_size", tamano_titulo)
	_puntaje_panel_final.add_theme_font_size_override("font_size", tamano_puntaje)
	_puntaje_panel_final.autowrap_mode = (
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
	if not _mensaje_error_bloqueante.is_empty():
		return
	_mensaje_error_bloqueante = mensaje_limpio

func _on_jugar_nuevamente_pressed() -> void:
	volver_al_mapa()

func _on_atrás_pressed() -> void:
	volver_al_mapa()

func volver_al_mapa() -> void:
	_limpiar_media_de_pregunta()
	Global.limpiar_sesion_nodo_jugable_activo()
	get_tree().change_scene_to_file(_ruta_escena_de_retorno)
