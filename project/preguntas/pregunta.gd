extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const GameStreakTrackerScript := preload(
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
const ContinuidadDePartidaDeNodoScript := preload(
	"res://mapas/logica/ContinuidadDePartidaDeNodo.gd"
)
const QuestionJsonLoaderScript := preload("res://preguntas/QuestionJsonLoader.gd")
const PresentadorContinuarJuegoScript := preload(
	"res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd"
)
const DEFAULT_TRACK_KEY := "celiaquia"
const DEFAULT_RETURN_SCENE := GameSceneRouter.MAP_SCENE_PATH
const CORRECT_ANSWER_SOUND := preload("res://assets-sistema/sonidos/bonus-points-190035.mp3")

const GAME_OVER_DEFAULT_FONT_SIZE := 81
const CONTENT_ERROR_TITLE_FONT_SIZE := 42
const CONTENT_ERROR_BODY_FONT_SIZE := 26
const SEGUNDOS_CONTINUACION_AUTOMATICA := 5.0


@onready var boton_1 = $Contenido/Preguntas/Boton1
@onready var boton_2 = $Contenido/Preguntas/Boton2

var dodge_offsets := [
	Vector2(120, 0),
	Vector2(-120, 0),
	Vector2(80, -20),
	Vector2(-80, 20)
]
var last_offset := Vector2.ZERO

var base_positions := {}
@export var quiz: ThemePreg
@export var nivel_id: int = 2
@export var track_key: String = "celiaquia"

var botones: Array[Button] = []
var indice_pregunta_actual: int = 0
var puntaje: int = 0
var bloqueado: bool = false
var ya_continuo: bool = false

var _nodo_actual: String = ""
var _tiene_sesion_de_mapa: bool = false
var _pertenece_a_partida_de_nodo: bool = false
var _ruta_escena_de_retorno: String = DEFAULT_RETURN_SCENE
var _mensaje_error_bloqueante: String = ""
var _plantillas_botones_respuesta: Array[Button] = []
var _post_game_streak_feedback: Dictionary = {}
var _post_game_flow_state: Dictionary = {}

var pregunta_actual: Preguntas:
	get : return quiz.theme[indice_pregunta_actual]

@onready var pregunta_label: Label = $Contenido/Informacion/Pregunta
@onready var _visual_panel: Panel = $Contenido/Informacion/Visual
@onready var _imagen_pregunta: TextureRect = $Contenido/Informacion/Visual/Imagen
@onready var _contenedor_respuestas: Control = $Contenido/Preguntas
@onready var _audio_player: AudioStreamPlayer2D = $Contenido/Audio
@onready var _contenido: Control = $Contenido
@onready var _panel_final: ColorRect = $Contenido/GameOver
@onready var _titulo_panel_final: Label = $Contenido/GameOver/Aciertos
@onready var _puntaje_panel_final: Label = $Contenido/GameOver/Puntaje
@onready var _boton_volver_mapa_final: Button = $Contenido/GameOver/JugarNuevamente
@onready var _continuar_juego = $Contenido/ContinuarJuego

@onready var _indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego

# Entrada del quiz
func _ready() -> void:
	puntaje = 0
	_registrar_posicion_base_boton(boton_1)
	_registrar_posicion_base_boton(boton_2)
	_reiniciar_cierre_del_quiz()
	_conectar_continuar_juego()

	_recolectar_botones_respuesta()
	configurar_quiz_desde_sesion()
	_configurar_indicador_de_progreso_de_juego()
	if not _puede_iniciar_quiz():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	if _cantidad_de_preguntas() > 1:
		quiz.theme.shuffle()
	mostrar_pregunta()


# Helpers de preparación
func _recolectar_botones_respuesta() -> void:
	botones.clear()
	_plantillas_botones_respuesta.clear()
	for boton_crudo in _contenedor_respuestas.get_children():
		var boton_respuesta: Button = boton_crudo as Button
		if boton_respuesta == null:
			continue
		_plantillas_botones_respuesta.append(boton_respuesta)
		_registrar_boton_respuesta(boton_respuesta)


func _registrar_boton_respuesta(boton_respuesta: Button) -> void:
	botones.append(boton_respuesta)
	_registrar_posicion_base_boton(boton_respuesta)
	boton_respuesta.pressed.connect(manejar_respuesta.bind(boton_respuesta))


func _registrar_posicion_base_boton(boton_respuesta: Button) -> void:
	if boton_respuesta == null:
		return
	if base_positions.has(boton_respuesta):
		return
	base_positions[boton_respuesta] = boton_respuesta.position


func dodge_button(button: Button) -> void:
	if button == null:
		return

	var base_pos: Vector2 = base_positions.get(button, button.position)
	base_positions[button] = base_pos
	var available_offsets = dodge_offsets.filter(
	func(o): return o != last_offset
	)

	var offset = available_offsets.pick_random()
	last_offset = offset	

	var target_pos = base_pos + offset

	var tween = create_tween()

	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		button,
		"scale",
		Vector2(0.95, 0.95),
		0.08
	)

	tween.parallel().tween_property(
		button,
		"rotation_degrees",
		randf_range(-4, 4),
		0.15
	)

	tween.parallel().tween_property(
		button,
		"position",
		target_pos,
		0.28
	)

	tween.tween_property(
		button,
		"scale",
		Vector2.ONE,
		0.08
	)
	await get_tree().create_timer(1.2).timeout

	var tween_back = create_tween()

	tween_back.tween_property(
		button,
		"position",
		base_pos,
		0.35
	)

func configurar_quiz_desde_sesion() -> void:
	_reiniciar_sesion_nodo()
	_mensaje_error_bloqueante = ""

	var contexto_sesion: Dictionary = ContextoSesionDeJuegoScript.obtener_contexto_jugable_actual()
	if contexto_sesion.is_empty():
		return

	var contexto_normalizado: Dictionary = ContextoSesionDeJuegoScript.normalizar_contexto_jugable(
		contexto_sesion,
		track_key,
		nivel_id,
		DEFAULT_RETURN_SCENE
	)
	_aplicar_contexto_sesion(contexto_normalizado)
	var resultado_quiz: Dictionary = QuestionJsonLoaderScript.cargar_tema_desde_sesion(
		contexto_normalizado
	)
	if not bool(resultado_quiz.get("ok", false)):
		_establecer_mensaje_de_error(
			str(resultado_quiz.get("error", "No se pudo cargar el contenido del nodo."))
		)
		return
	quiz = resultado_quiz.get("data", {}).get("theme") as ThemePreg


func _reiniciar_sesion_nodo() -> void:
	_tiene_sesion_de_mapa = false
	_pertenece_a_partida_de_nodo = false
	_nodo_actual = ""
	_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE
	_post_game_streak_feedback = {}
	_post_game_flow_state = {}


func _aplicar_contexto_sesion(contexto_sesion: Dictionary) -> void:
	track_key = str(contexto_sesion.get("track_key", track_key)).strip_edges()
	nivel_id = int(contexto_sesion.get("level_number", contexto_sesion.get("nivel_id", nivel_id)))
	_nodo_actual = str(contexto_sesion.get("node_key", "")).strip_edges()
	_pertenece_a_partida_de_nodo = bool(
		contexto_sesion.get("pertenece_a_partida_de_nodo", false)
	)
	_ruta_escena_de_retorno = str(
		contexto_sesion.get("return_to", DEFAULT_RETURN_SCENE)
	).strip_edges()
	if _ruta_escena_de_retorno.is_empty():
		_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE
	_tiene_sesion_de_mapa = bool(
		contexto_sesion.get("came_from_map", not _nodo_actual.is_empty())
	)


func _es_juego_de_partida_de_nodo() -> bool:
	return _pertenece_a_partida_de_nodo


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


func _conectar_continuar_juego() -> void:
	if _continuar_juego == null:
		return
	if _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.connect("continuar_solicitado", Callable(self, "_al_presionar_continuar"))


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


# Gameplay del quiz
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
		nuevo_boton.position = _calcular_posicion_boton_respuesta(botones.size())
		_contenedor_respuestas.add_child(nuevo_boton)
		_registrar_boton_respuesta(nuevo_boton)


func _configurar_boton_respuesta(boton_respuesta: Button, texto_respuesta: String) -> void:
	boton_respuesta.show()
	boton_respuesta.text = _texto_display(texto_respuesta)
	boton_respuesta.tooltip_text = texto_respuesta
	boton_respuesta.set_meta("respuesta", texto_respuesta)
	boton_respuesta.modulate = Color.WHITE
	boton_respuesta.disabled = false
	boton_respuesta.scale = Vector2.ONE
	boton_respuesta.rotation_degrees = 0
	boton_respuesta.add_theme_font_size_override("font_size", _font_size_para(texto_respuesta))


func _calcular_posicion_boton_respuesta(indice_boton: int) -> Vector2:
	var origen: Vector2 = boton_1.position if boton_1 != null else Vector2.ZERO
	var separacion_vertical := 157.0
	if boton_1 != null and boton_2 != null:
		var distancia_plantillas: float = boton_2.position.y - boton_1.position.y
		if distancia_plantillas > 0.0:
			separacion_vertical = distancia_plantillas
	return origen + Vector2(0.0, separacion_vertical * indice_boton)


const MAX_DISPLAY_CHARS := 55

func _texto_display(texto: String) -> String:
	if texto.length() <= MAX_DISPLAY_CHARS:
		return texto
	var corte: int = texto.rfind(" ", MAX_DISPLAY_CHARS)
	if corte < MAX_DISPLAY_CHARS / 2:
		corte = MAX_DISPLAY_CHARS
	return texto.substr(0, corte) + "…"


func _font_size_para(texto: String) -> int:
	var largo: int = texto.length()
	if largo > 40:
		return 14
	if largo > 25:
		return 17
	return 20


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

	var respuesta_elegida: String = str(boton.get_meta("respuesta"))
	var es_correcta: bool = pregunta_actual.correct == respuesta_elegida

	_mostrar_feedback_respuesta(boton, es_correcta)

	if es_correcta:

		puntaje += 1

		for boton_respuesta in botones:
			boton_respuesta.disabled = true

		await get_tree().create_timer(1.2).timeout
		_finalizar_quiz()
		return

	await dodge_button(boton)

	await get_tree().create_timer(0.4).timeout

	bloqueado = false

	for boton_respuesta in botones:
		boton_respuesta.disabled = false


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

	boton.modulate = Color(1.0, 0.4, 0.4)
	for unused_index in 5:
		tween.tween_property(boton, "rotation_degrees", 8, 0.03)
		tween.tween_property(boton, "rotation_degrees", -8, 0.03)
	tween.tween_property(boton, "rotation_degrees", 0, 0.05)


# Finalización de partida
func _finalizar_quiz() -> void:
	_finalizar_partida()


func _finalizar_partida() -> void:
	var cantidad_preguntas: int = _cantidad_de_preguntas()
	if not _es_juego_de_partida_de_nodo():
		_finalizar_pregunta_normal(cantidad_preguntas)
	_mostrar_cierre_del_quiz(cantidad_preguntas)


func _debe_abrir_siguiente_juego_de_partida() -> bool:
	if not _es_juego_de_partida_de_nodo():
		return false
	return ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(get_tree())


func _finalizar_pregunta_normal(cantidad_preguntas: int) -> void:
	var previous_streak: Dictionary = Global.obtener_estado_racha()

	if _tiene_sesion_de_mapa:
		_guardar_progreso_de_mapa(cantidad_preguntas)
	else:
		Global.marcar_nivel_completado(track_key, nivel_id)
		SaveManager.registrar_nivel_completado(track_key, nivel_id)

	SaveManager.registrar_sesion_preguntas_completada(cantidad_preguntas, puntaje)
	var updated_streak: Dictionary = Global.obtener_estado_racha()
	_on_questions_finished(previous_streak, updated_streak)


func _mostrar_cierre_del_quiz(cantidad_preguntas: int) -> void:
	bloqueado = true
	_ocultar_continuacion_automatica()
	_limpiar_media_de_pregunta()
	for boton_respuesta in botones:
		boton_respuesta.disabled = true

	if _debe_mostrar_continuar_de_partida_de_nodo():
		_ocultar_resultado_final_de_pregunta()
		_mostrar_continuacion_automatica(_debe_abrir_siguiente_juego_de_partida())
		return

	var total_preguntas: int = max(1, cantidad_preguntas)
	_configurar_panel_final(
		"Aciertos",
		"%d/%d" % [puntaje, total_preguntas],
		true,
		true
	)

	if _boton_volver_mapa_final != null:
		_boton_volver_mapa_final.hide()
		_boton_volver_mapa_final.disabled = true
	_mostrar_continuacion_automatica(false)


func _debe_mostrar_continuar_de_partida_de_nodo() -> bool:
	return _es_juego_de_partida_de_nodo()


func _ocultar_resultado_final_de_pregunta() -> void:
	if _panel_final != null:
		_panel_final.hide()
	if _boton_volver_mapa_final != null:
		_boton_volver_mapa_final.hide()
		_boton_volver_mapa_final.disabled = true


func _reiniciar_cierre_del_quiz() -> void:
	ya_continuo = false
	_ocultar_continuacion_automatica()
	if _panel_final != null:
		_panel_final.hide()
	if _boton_volver_mapa_final != null:
		_boton_volver_mapa_final.show()
		_boton_volver_mapa_final.disabled = false


func _mostrar_continuacion_automatica(hay_siguiente_juego: bool) -> void:
	if _boton_volver_mapa_final != null:
		_boton_volver_mapa_final.hide()
		_boton_volver_mapa_final.disabled = true
	PresentadorContinuarJuegoScript.mostrar(
		_continuar_juego,
		hay_siguiente_juego,
		int(SEGUNDOS_CONTINUACION_AUTOMATICA)
	)


func _ocultar_continuacion_automatica() -> void:
	PresentadorContinuarJuegoScript.ocultar(_continuar_juego)



func _continuar_partida_de_nodo_si_corresponde() -> bool:
	if not _es_juego_de_partida_de_nodo():
		return false
	if not _debe_abrir_siguiente_juego_de_partida():
		return false
	return ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(
		get_tree(),
		Callable(self, "_limpiar_media_de_pregunta"),
		Callable(self, "_limpiar_estado_local_de_partida_en_pregunta")
	)


func _limpiar_estado_local_de_partida_en_pregunta() -> void:
	_limpiar_media_de_pregunta()
	_pertenece_a_partida_de_nodo = false


func _guardar_progreso_de_mapa(_cantidad_preguntas: int) -> void:
	if not _nodo_actual.is_empty():
		Global.marcar_nodo_jugable_completado(track_key, _nodo_actual)


func _on_questions_finished(
	previous_streak: Dictionary,
	updated_streak: Dictionary
) -> void:
	var completion_context: Dictionary = ContextoFinalizacionDeJuegoScript.construir(
		"question",
		track_key,
		nivel_id,
		Global.obtener_pista_nivel_cantidad(track_key),
		track_key == DEFAULT_TRACK_KEY,
		_tiene_sesion_de_mapa,
		_nodo_actual,
		_ruta_escena_de_retorno,
		"pregunta._on_questions_finished"
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




func _on_timer_siguiente_nodo_timeout() -> void:
	_al_presionar_continuar()


func continuar_al_siguiente_nodo() -> void:
	_al_presionar_continuar()


func _al_presionar_continuar() -> void:
	if ya_continuo:
		return

	ya_continuo = true
	_ocultar_continuacion_automatica()
	if _continuar_partida_de_nodo_si_corresponde():
		return
	if _es_juego_de_partida_de_nodo():
		_finalizar_ultima_pregunta_de_partida()
		return
	_continuar_despues_de_ensenanza(true)


func _finalizar_ultima_pregunta_de_partida() -> void:
	ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(get_tree())
	_finalizar_pregunta_normal(_cantidad_de_preguntas())
	_limpiar_estado_local_de_partida_en_pregunta()
	_continuar_despues_de_ensenanza(true)


func _on_flecha_derecha_pressed() -> void:
	_al_presionar_continuar()


func _on_teaching_finished(timer_finished: bool) -> void:
	_continuar_despues_de_ensenanza(timer_finished)


func _continuar_despues_de_ensenanza(timer_finished: bool) -> void:
	if not _has_post_game_flow_state():
		_return_to_map_scene()
		return

	# La escena solo informa que termino la UI; el controlador decide el destino.
	PostGameFlowControllerScript.navigate_after_teaching(
		get_tree(),
		_take_post_game_flow_state(),
		_take_post_game_streak_feedback(),
		timer_finished
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
	_ocultar_continuacion_automatica()
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


# Navegación y continuidad
func _on_jugar_nuevamente_pressed() -> void:
	volver_al_mapa()


func _on_atras_pressed() -> void:
	if _es_juego_de_partida_de_nodo():
		_cancelar_partida_de_nodo_desde_juego()
		return
	volver_al_mapa()






func volver_al_mapa() -> void:
	if _es_juego_de_partida_de_nodo():
		_cancelar_partida_de_nodo_desde_juego()
		return
	if _has_post_game_flow_state():
		_on_teaching_finished(false)
		return
	_return_to_map_scene()


func _cancelar_partida_de_nodo_desde_juego() -> void:
	Global.finalizar_partida_de_nodo()
	Global.limpiar_sesion_nodo_jugable_activo()
	_ocultar_continuacion_automatica()
	_limpiar_media_de_pregunta()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_de_retorno
	)


func _return_to_map_scene() -> void:
	_ocultar_continuacion_automatica()
	_limpiar_media_de_pregunta()
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_ruta_escena_de_retorno
	)
	
	
