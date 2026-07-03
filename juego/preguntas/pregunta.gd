extends Node2D
class_name EscenaPregunta


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
const NodoRuntimeScript := preload("res://sistemas/NodoRuntime.gd")
const QuestionJsonLoaderScript := preload("res://preguntas/QuestionJsonLoader.gd")
const ResultadoDeMiniJuegoScript := preload("res://modalidades/ResultadoDeMiniJuego.gd")
const PresentadorEnsenanzasScript := preload("res://ensenanzas/PresentadorEnsenanzas.gd")
const PresentadorContinuarJuegoScript := preload(
	"res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd"
)
const DEFAULT_TRACK_KEY := "celiaquia"
const DEFAULT_RETURN_SCENE := "res://mapas/MapScene.tscn"
const CORRECT_ANSWER_SOUND_PATH := "res://assets-sistema/sonidos/bonus-points-190035.mp3"
const LOG_PREFIX_QUIZ := "[Quiz]"
const LOG_PREFIX_QUIZ_LAYOUT := "[QuizLayout]"
const LOG_PREFIX_TEACHING := "[Teaching]"

const GAME_OVER_DEFAULT_FONT_SIZE := 81
const CONTENT_ERROR_TITLE_FONT_SIZE := 42
const CONTENT_ERROR_BODY_FONT_SIZE := 26
const SEGUNDOS_CONTINUACION_AUTOMATICA := 5.0

@onready var titulo_nivel: Label = $Contenido/TituloNivel/Label


@onready var _layout_preguntas_2: Control = $Contenido/Preguntas
@onready var _layout_preguntas_3: Control = $Contenido/Preguntasx3
@onready var _layout_preguntas_4: Control = $Contenido/Preguntasx4

@onready var boton_1: Button = $Contenido/Preguntas/Boton1
@onready var boton_2: Button = $Contenido/Preguntas/Boton2
@onready var boton_3: Button = $Contenido/Preguntasx3/Boton3
@onready var boton_4: Button = $Contenido/Preguntasx3/Boton4
@onready var boton_5: Button = $Contenido/Preguntasx3/Boton5
@onready var boton_6: Button = $Contenido/Preguntasx4/Boton6
@onready var boton_7: Button = $Contenido/Preguntasx4/Boton7
@onready var boton_8: Button = $Contenido/Preguntasx4/Boton8
@onready var boton_9: Button = $Contenido/Preguntasx4/Boton9

var dodge_offsets := [
	Vector2(120, 0),
	Vector2(-120, 0),
	Vector2(80, -20),
	Vector2(-80, 20)
]
var last_offset := Vector2.ZERO

var base_positions := {}
var _base_scales := {}
var _base_rotations := {}
@export var quiz: ThemePreg
@export var nivel_id: int = 2
@export var track_key: String = "celiaquia"

var botones: Array[Button] = []
var _todos_los_botones: Array[Button] = []
var _botones_layout_2: Array[Button] = []
var _botones_layout_3: Array[Button] = []
var _botones_layout_4: Array[Button] = []
var indice_pregunta_actual: int = 0
var puntaje: int = 0
var bloqueado: bool = false
var ya_continuo: bool = false

var _nodo_actual: String = ""
var _teaching_key: String = ""
var _tiene_sesion_de_mapa: bool = false
var _pertenece_a_partida_de_nodo: bool = false
var _ruta_escena_de_retorno: String = DEFAULT_RETURN_SCENE
var _mensaje_error_bloqueante: String = ""
var _post_game_streak_feedback: Dictionary = {}
var _post_game_flow_state: Dictionary = {}
var _correct_answer_sound: AudioStream = null
var _typewriter: TypewriterEffect = TypewriterEffect.new()

var pregunta_actual: Preguntas:
	get : return quiz.theme[indice_pregunta_actual]

@onready var pregunta_label: Label = $Contenido/Informacion/Pregunta
@onready var _visual_panel: Panel = $Contenido/Informacion/Visual
@onready var _imagen_pregunta: TextureRect = $Contenido/Informacion/Visual/Imagen
@onready var _audio_player: AudioStreamPlayer2D = $Contenido/Audio
@onready var _panel_final: ColorRect = $Contenido/GameOver
@onready var _titulo_panel_final: Label = $Contenido/GameOver/Aciertos
@onready var _puntaje_panel_final: Label = $Contenido/GameOver/Puntaje
@onready var _boton_volver_mapa_final: Button = $Contenido/GameOver/JugarNuevamente
@onready var _continuar_juego = $Contenido/ContinuarJuego

@onready var _indicador_de_progreso_de_juego = $IndicadorProgresoDeJuego
@onready var _progress_bar = get_node_or_null("ProgressBar")

var _activity_started_msec: int = 0

# Entrada del quiz
func _ready() -> void:
	_activity_started_msec = Time.get_ticks_msec()
	print("[TimeTracker] started quiz")
	puntaje = 0
	_configurar_layouts_de_opciones()
	_reiniciar_cierre_del_quiz()
	_conectar_continuar_juego()
	titulo_nivel.text = "Celiaquía"
	_cargar_datos_pregunta()
	_configurar_indicador_de_progreso_de_juego()
	if not _puede_iniciar_quiz():
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return
	if _cantidad_de_preguntas() > 1:
		quiz.theme.shuffle()
	_mostrar_pregunta()


# Helpers de preparación
func _configurar_layouts_de_opciones() -> void:
	_botones_layout_2 = [boton_1, boton_2]
	_botones_layout_3 = [boton_3, boton_4, boton_5]
	_botones_layout_4 = [boton_6, boton_7, boton_8, boton_9]

	botones.clear()
	_todos_los_botones.clear()
	_registrar_botones_de_layout(_botones_layout_2)
	_registrar_botones_de_layout(_botones_layout_3)
	_registrar_botones_de_layout(_botones_layout_4)
	_ocultar_todos_los_layouts_de_opciones()


func _registrar_botones_de_layout(botones_layout: Array[Button]) -> void:
	for boton_respuesta in botones_layout:
		_registrar_boton_respuesta(boton_respuesta)


func _registrar_boton_respuesta(boton_respuesta: Button) -> void:
	if boton_respuesta == null:
		return
	if not _todos_los_botones.has(boton_respuesta):
		_todos_los_botones.append(boton_respuesta)
	_registrar_posicion_base_boton(boton_respuesta)
	_registrar_transform_base_boton(boton_respuesta)
	var callback := _on_opcion_seleccionada.bind(boton_respuesta)
	if not boton_respuesta.pressed.is_connected(callback):
		boton_respuesta.pressed.connect(callback)


func _registrar_posicion_base_boton(boton_respuesta: Button) -> void:
	if boton_respuesta == null:
		return
	if base_positions.has(boton_respuesta):
		return
	base_positions[boton_respuesta] = boton_respuesta.position


func _registrar_transform_base_boton(boton_respuesta: Button) -> void:
	if boton_respuesta == null:
		return
	if not _base_scales.has(boton_respuesta):
		_base_scales[boton_respuesta] = boton_respuesta.scale
	if not _base_rotations.has(boton_respuesta):
		_base_rotations[boton_respuesta] = boton_respuesta.rotation_degrees


func _obtener_escala_base_boton(boton_respuesta: Button) -> Vector2:
	return _base_scales.get(boton_respuesta, boton_respuesta.scale)


func _obtener_rotacion_base_boton(boton_respuesta: Button) -> float:
	return float(_base_rotations.get(boton_respuesta, boton_respuesta.rotation_degrees))


func _escalar_escala_base(boton_respuesta: Button, factor_x: float, factor_y: float) -> Vector2:
	var escala_base: Vector2 = _obtener_escala_base_boton(boton_respuesta)
	return Vector2(escala_base.x * factor_x, escala_base.y * factor_y)


func esquivar_boton(button: Button) -> void:
	if button == null:
		return

	var base_pos: Vector2 = base_positions.get(button, button.position)
	var base_scale: Vector2 = _obtener_escala_base_boton(button)
	var base_rotation: float = _obtener_rotacion_base_boton(button)
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
		_escalar_escala_base(button, 0.95, 0.95),
		0.08
	)

	tween.parallel().tween_property(
		button,
		"rotation_degrees",
		base_rotation + randf_range(-4, 4),
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
		base_scale,
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
	tween_back.parallel().tween_property(button, "scale", base_scale, 0.2)
	tween_back.parallel().tween_property(button, "rotation_degrees", base_rotation, 0.2)

func _cargar_datos_pregunta() -> void:
	configurar_quiz_desde_sesion()
	if quiz != null:
		print(
			LOG_PREFIX_QUIZ,
			" activity=",
			_nodo_actual,
			" options=",
			_cantidad_de_opciones_actuales()
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
	_teaching_key = str(
		resultado_quiz.get("data", {}).get("teaching_key", "")
	).strip_edges()


func _reiniciar_sesion_nodo() -> void:
	_tiene_sesion_de_mapa = false
	_pertenece_a_partida_de_nodo = false
	_nodo_actual = ""
	_teaching_key = ""
	_ruta_escena_de_retorno = DEFAULT_RETURN_SCENE
	_post_game_streak_feedback = {}
	_post_game_flow_state = {}


func _aplicar_contexto_sesion(contexto_sesion: Dictionary) -> void:
	track_key = ContextoSesionDeJuegoScript.leer_track_key(contexto_sesion, track_key)
	nivel_id = ContextoSesionDeJuegoScript.leer_nivel_id(contexto_sesion, nivel_id)
	_nodo_actual = ContextoSesionDeJuegoScript.leer_node_key(contexto_sesion)
	_pertenece_a_partida_de_nodo = ContextoSesionDeJuegoScript.leer_pertenece_a_nodo(contexto_sesion)
	_ruta_escena_de_retorno = ContextoSesionDeJuegoScript.leer_return_to(contexto_sesion, DEFAULT_RETURN_SCENE)
	_tiene_sesion_de_mapa = ContextoSesionDeJuegoScript.leer_came_from_map(contexto_sesion)


func _obtener_estado_racha_global() -> Dictionary:
	var global_autoload := ContextoSesionDeJuegoScript.obtener_global()
	if global_autoload == null or not global_autoload.has_method("obtener_estado_racha"):
		return {}
	var estado_racha: Variant = global_autoload.call("obtener_estado_racha")
	if estado_racha is Dictionary:
		return (estado_racha as Dictionary).duplicate(true)
	return {}


func _obtener_cantidad_de_niveles_de_pista() -> int:
	var global_autoload := ContextoSesionDeJuegoScript.obtener_global()
	if global_autoload == null or not global_autoload.has_method("obtener_pista_nivel_cantidad"):
		return 1
	return int(global_autoload.call("obtener_pista_nivel_cantidad", track_key))


func _es_juego_de_partida_de_nodo() -> bool:
	return _pertenece_a_partida_de_nodo


func _configurar_indicador_de_progreso_de_juego() -> void:
	# Ocultar el badge "Juego X/Y" — la barra inferior es el único indicador de progreso
	if _indicador_de_progreso_de_juego != null:
		_indicador_de_progreso_de_juego.hide()
	# Actualizar barra inferior con la posición actual dentro del nodo
	if _progress_bar == null:
		return
	var contexto: Dictionary = ContextoSesionDeJuegoScript.obtener_modelo_indicador_actual()
	var actual: int = int(contexto.get("actual", 1))
	var total: int = int(contexto.get("total", 1))
	if _progress_bar.has_method("actualizar_progreso"):
		_progress_bar.actualizar_progreso(actual, total)


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


func _cantidad_de_opciones_actuales() -> int:
	if quiz == null or quiz.theme.is_empty():
		return 0
	if indice_pregunta_actual >= quiz.theme.size():
		return 0
	return pregunta_actual.opciones.size()


# Gameplay del quiz
func mostrar_pregunta() -> void:
	_mostrar_pregunta()


func _mostrar_pregunta() -> void:
	bloqueado = false

	if quiz == null:
		_establecer_mensaje_de_error("No hay quiz asignado para cargar.")
		_mostrar_error_bloqueante(_mensaje_error_bloqueante)
		return

	if indice_pregunta_actual >= _cantidad_de_preguntas():
		_finalizar_quiz()
		return

	_mostrar_visual_de_pregunta(pregunta_actual)
	_crear_opciones(pregunta_actual.opciones)
	_typewriter.iniciar(self, func(t: String): pregunta_label.text = t, pregunta_actual.info_pregunta)


func _crear_opciones(opciones_actuales: Array[String]) -> void:
	_mostrar_opciones(opciones_actuales)


func _mostrar_opciones(opciones_actuales: Array[String]) -> void:
	_mostrar_layout_por_cantidad(opciones_actuales.size())
	_cargar_opciones_en_botones(opciones_actuales, botones)


func _mostrar_layout_por_cantidad(cantidad_opciones: int) -> void:
	botones = _obtener_botones_para_cantidad(cantidad_opciones)


func _obtener_botones_para_cantidad(cantidad_opciones: int) -> Array[Button]:
	_ocultar_todos_los_layouts_de_opciones()
	if cantidad_opciones <= 0:
		push_warning(
			"%s options=%d sin opciones jugables." % [
				LOG_PREFIX_QUIZ_LAYOUT,
				cantidad_opciones
			]
		)
		return []

	var cantidad_layout: int = _resolver_cantidad_layout(cantidad_opciones)
	if cantidad_layout != cantidad_opciones:
		push_warning(
			"%s options=%d fallback=%s" % [
				LOG_PREFIX_QUIZ_LAYOUT,
				cantidad_opciones,
				_nombre_layout_para_cantidad(cantidad_layout)
			]
		)

	var botones_layout: Array[Button] = []
	match cantidad_layout:
		2:
			_layout_preguntas_2.show()
			botones_layout = _botones_layout_2
		3:
			_layout_preguntas_3.show()
			botones_layout = _botones_layout_3
		_:
			_layout_preguntas_4.show()
			botones_layout = _botones_layout_4

	print(
		LOG_PREFIX_QUIZ_LAYOUT,
		" options=",
		cantidad_opciones,
		" layout=",
		_nombre_layout_para_cantidad(cantidad_layout)
	)
	return botones_layout


func _resolver_cantidad_layout(cantidad_opciones: int) -> int:
	if cantidad_opciones <= 2:
		return 2
	if cantidad_opciones == 3:
		return 3
	return 4


func _nombre_layout_para_cantidad(cantidad_layout: int) -> String:
	match cantidad_layout:
		2:
			return _layout_preguntas_2.name
		3:
			return _layout_preguntas_3.name
		4:
			return _layout_preguntas_4.name
		_:
			return "desconocido"


func _ocultar_todos_los_layouts_de_opciones() -> void:
	botones.clear()
	if _layout_preguntas_2 != null:
		_layout_preguntas_2.hide()
	if _layout_preguntas_3 != null:
		_layout_preguntas_3.hide()
	if _layout_preguntas_4 != null:
		_layout_preguntas_4.hide()
	for boton_respuesta in _todos_los_botones:
		_ocultar_boton_respuesta(boton_respuesta)


func _cargar_opciones_en_botones(
	opciones_actuales: Array[String],
	botones_layout: Array[Button]
) -> void:
	if botones_layout.is_empty():
		return

	var cantidad_a_cargar: int = min(opciones_actuales.size(), botones_layout.size())
	if opciones_actuales.size() > botones_layout.size():
		push_warning(
			"%s options=%d buttons=%d; se omiten excedentes." % [
				LOG_PREFIX_QUIZ_LAYOUT,
				opciones_actuales.size(),
				botones_layout.size()
			]
		)

	for indice_boton in range(botones_layout.size()):
		var boton_respuesta: Button = botones_layout[indice_boton]
		if indice_boton >= cantidad_a_cargar:
			_ocultar_boton_respuesta(boton_respuesta)
			continue
		_configurar_boton_respuesta(boton_respuesta, opciones_actuales[indice_boton])


func _configurar_boton_respuesta(boton_respuesta: Button, texto_respuesta: String) -> void:
	boton_respuesta.show()
	_restablecer_estado_visual_boton(boton_respuesta)
	var texto_visible := _texto_display(texto_respuesta)
	_set_texto_boton_opcion(boton_respuesta, texto_visible, _font_size_para(texto_respuesta))
	boton_respuesta.tooltip_text = ""
	boton_respuesta.set_meta("respuesta", texto_respuesta)
	boton_respuesta.disabled = false


const MAX_DISPLAY_CHARS := 55

func _texto_display(texto: String) -> String:
	if texto.length() <= MAX_DISPLAY_CHARS:
		return texto
	var corte: int = texto.rfind(" ", MAX_DISPLAY_CHARS)
	if corte < int(MAX_DISPLAY_CHARS / 2.0):
		corte = MAX_DISPLAY_CHARS
	return texto.substr(0, corte) + "…"


func _font_size_para(texto: String) -> int:
	var largo: int = texto.length()
	if largo > 40:
		return 14
	if largo > 25:
		return 17
	return 20


func _restablecer_estado_visual_boton(boton_respuesta: Button) -> void:
	boton_respuesta.modulate = Color.WHITE
	boton_respuesta.scale = _obtener_escala_base_boton(boton_respuesta)
	boton_respuesta.rotation_degrees = _obtener_rotacion_base_boton(boton_respuesta)


func _ocultar_boton_respuesta(boton_respuesta: Button) -> void:
	_restablecer_estado_visual_boton(boton_respuesta)
	boton_respuesta.hide()
	boton_respuesta.text = ""
	var label_ocultar := _buscar_label_de_boton(boton_respuesta)
	if label_ocultar:
		label_ocultar.text = ""
	boton_respuesta.disabled = true
	boton_respuesta.tooltip_text = ""
	boton_respuesta.set_meta("respuesta", "")


func _buscar_label_de_boton(boton: Button) -> Label:
	for nombre in ["TextoOpcion", "Texto", "Label", "OptionLabel"]:
		var nodo := boton.get_node_or_null(nombre)
		if nodo is Label:
			return nodo as Label
	return null


func _set_texto_boton_opcion(boton: Button, texto: String, font_size_visual: int) -> void:
	var label := _buscar_label_de_boton(boton)
	if label:
		label.text = texto
		boton.text = ""
		var scale_x: float = boton.scale.x if boton.scale.x > 0.01 else 1.0
		label.add_theme_font_size_override("font_size", int(round(float(font_size_visual) / scale_x)))
		print("[QuizOption] button=", boton.name, " label=", label.name, " found=true text=\"", texto.left(30), "\"")
	else:
		boton.text = texto
		boton.add_theme_font_size_override("font_size", font_size_visual)


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
	_on_opcion_seleccionada(boton)


func _on_opcion_seleccionada(boton: Button) -> void:
	if bloqueado:
		return

	_typewriter.solicitar_salto()
	bloqueado = true

	var respuesta_elegida: String = str(boton.get_meta("respuesta"))
	var es_correcta: bool = _validar_respuesta(respuesta_elegida)
	print(LOG_PREFIX_QUIZ, " selected=", respuesta_elegida, " correct=", es_correcta)

	if es_correcta:
		await _mostrar_feedback_correcto(boton)
		_finalizar_pregunta()
		return

	await _mostrar_feedback_error(boton)
	bloqueado = false
	_set_opciones_habilitadas(true)


func _validar_respuesta(respuesta_elegida: String) -> bool:
	return pregunta_actual.correct == respuesta_elegida


func _mostrar_feedback_correcto(boton: Button) -> void:
	puntaje += 1
	_set_opciones_habilitadas(false)
	_mostrar_feedback_respuesta(boton, true)
	boton.disabled = false
	var global_autoload := ContextoSesionDeJuegoScript.obtener_global()
	if global_autoload != null and global_autoload.has_method("registrar_resultado_mini_juego"):
		global_autoload.call("registrar_resultado_mini_juego", true)
	await get_tree().create_timer(1.2).timeout


func _mostrar_feedback_error(boton: Button) -> void:
	_mostrar_feedback_respuesta(boton, false)
	var global_autoload := ContextoSesionDeJuegoScript.obtener_global()
	if global_autoload != null and global_autoload.has_method("registrar_resultado_mini_juego"):
		global_autoload.call("registrar_resultado_mini_juego", false)
	await esquivar_boton(boton)
	await get_tree().create_timer(0.4).timeout


func _set_opciones_habilitadas(habilitadas: bool) -> void:
	for boton_respuesta in botones:
		boton_respuesta.disabled = not habilitadas


func _finalizar_pregunta() -> void:
	indice_pregunta_actual += 1
	if indice_pregunta_actual >= _cantidad_de_preguntas():
		_finalizar_quiz()
		return
	mostrar_pregunta()


func _mostrar_feedback_respuesta(boton: Button, es_correcta: bool) -> void:
	var tween = create_tween()
	var base_scale: Vector2 = _obtener_escala_base_boton(boton)
	var base_rotation: float = _obtener_rotacion_base_boton(boton)
	var correct_answer_sound := _obtener_sonido_respuesta_correcta()
	if es_correcta and _audio_player != null and correct_answer_sound != null:
		_audio_player.stop()
		_audio_player.stream = correct_answer_sound
		_audio_player.play()

	if es_correcta:
		# Tinte verde suave: Color(0,1,0) puro multiplicaba a cero los canales R/B
		# del fondo del boton y lo hacia ver "transparenton" en pantalla.
		boton.modulate = MiPaleta.FEEDBACK_OK
		tween.tween_property(boton, "scale", _escalar_escala_base(boton, 1.08, 0.92), 0.08)
		tween.tween_property(boton, "scale", _escalar_escala_base(boton, 0.95, 1.05), 0.08)
		tween.tween_property(boton, "scale", _escalar_escala_base(boton, 1.03, 0.97), 0.08)
		tween.tween_property(boton, "scale", base_scale, 0.1)
		return

	boton.modulate = MiPaleta.FEEDBACK_ERROR
	for unused_index in 5:
		tween.tween_property(boton, "rotation_degrees", base_rotation + 8, 0.03)
		tween.tween_property(boton, "rotation_degrees", base_rotation - 8, 0.03)
	tween.tween_property(boton, "rotation_degrees", base_rotation, 0.05)


func _obtener_sonido_respuesta_correcta() -> AudioStream:
	if _correct_answer_sound != null:
		return _correct_answer_sound
	_correct_answer_sound = load(CORRECT_ANSWER_SOUND_PATH) as AudioStream
	return _correct_answer_sound


# Finalización de partida
func _finalizar_quiz() -> void:
	print(LOG_PREFIX_QUIZ, " completed activity=", _nodo_actual)
	_finalizar_partida()


func _finalizar_partida() -> void:
	var cantidad_preguntas: int = _cantidad_de_preguntas()
	if not _es_juego_de_partida_de_nodo():
		_finalizar_pregunta_normal(cantidad_preguntas)
	_mostrar_cierre_del_quiz(cantidad_preguntas)


func _debe_abrir_siguiente_juego_de_partida() -> bool:
	if not _es_juego_de_partida_de_nodo():
		return false
	return NodoRuntimeScript.hay_siguiente_mini_juego(get_tree())


func _finalizar_pregunta_normal(cantidad_preguntas: int) -> void:
	var global_autoload := ContextoSesionDeJuegoScript.obtener_global()
	var save_manager := ContextoSesionDeJuegoScript.obtener_save_manager()
	var previous_streak: Dictionary = _obtener_estado_racha_global()

	if _tiene_sesion_de_mapa:
		_guardar_progreso_de_mapa(cantidad_preguntas)
	else:
		if global_autoload != null and global_autoload.has_method("marcar_nivel_completado"):
			global_autoload.call("marcar_nivel_completado", track_key, nivel_id)
		if save_manager != null and save_manager.has_method("registrar_nivel_completado"):
			save_manager.call("registrar_nivel_completado", track_key, nivel_id)

	if save_manager != null and save_manager.has_method("registrar_sesion_preguntas_completada"):
		save_manager.call("registrar_sesion_preguntas_completada", cantidad_preguntas, puntaje)
	var updated_streak: Dictionary = _obtener_estado_racha_global()
	_on_questions_finished(previous_streak, updated_streak)


func _mostrar_cierre_del_quiz(cantidad_preguntas: int) -> void:
	bloqueado = true
	_ocultar_continuacion_automatica()
	_limpiar_media_de_pregunta()
	for boton_respuesta in botones:
		boton_respuesta.disabled = true

	if _es_juego_de_partida_de_nodo() and PostGameFlowControllerScript.es_cierre_de_nodo_mapa(get_tree()):
		if _intentar_mostrar_ensenanza_esc(cantidad_preguntas):
			return
		_finalizar_actividad(true)
		return

	_mostrar_cierre_post_ensenanza(cantidad_preguntas)


func _intentar_mostrar_ensenanza_esc(_cantidad_preguntas: int) -> bool:
	if _teaching_key.is_empty():
		return false
	var mostrado: bool = PresentadorEnsenanzasScript.mostrar_en_host(
		self,
		_teaching_key,
		Callable(self, "_continuar_desde_ensenanza_esc"),
		track_key,
		_nodo_actual,
		nivel_id
	)
	if mostrado:
		print("%s modo=EnsenanzaEsc key=%s" % [LOG_PREFIX_TEACHING, _teaching_key])
	return mostrado


func _continuar_desde_ensenanza_esc() -> void:
	ya_continuo = false
	_al_presionar_continuar()


func _mostrar_cierre_post_ensenanza(cantidad_preguntas: int) -> void:
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
	return NodoRuntimeScript.finalizar_mini_juego(
		get_tree(),
		Callable(self, "_limpiar_media_de_pregunta"),
		Callable(self, "_limpiar_estado_local_de_partida_en_pregunta")
	)


func _limpiar_estado_local_de_partida_en_pregunta() -> void:
	if _progress_bar != null and _progress_bar.has_method("completar_progreso"):
		_progress_bar.completar_progreso()
	_limpiar_media_de_pregunta()
	_pertenece_a_partida_de_nodo = false


## Cumple el contrato de ModalidadBase. Devuelve el resultado de este mini juego de pregunta.
func obtener_resultado() -> ResultadoDeMiniJuego:
	var total := maxi(1, _cantidad_de_preguntas())
	return ResultadoDeMiniJuegoScript.crear_detallado(
		"pregunta", puntaje, total - puntaje, total
	)


func _guardar_progreso_de_mapa(_cantidad_preguntas: int) -> void:
	if not _nodo_actual.is_empty():
		var global_autoload := ContextoSesionDeJuegoScript.obtener_global()
		if global_autoload != null and global_autoload.has_method("marcar_nodo_jugable_completado"):
			global_autoload.call("marcar_nodo_jugable_completado", track_key, _nodo_actual)


func _on_questions_finished(
	previous_streak: Dictionary,
	updated_streak: Dictionary
) -> void:
	var completion_context: Dictionary = ContextoFinalizacionDeJuegoScript.construir(
		"question",
		track_key,
		nivel_id,
		_obtener_cantidad_de_niveles_de_pista(),
		track_key == DEFAULT_TRACK_KEY,
		_tiene_sesion_de_mapa,
		_nodo_actual,
		_ruta_escena_de_retorno,
		"pregunta._on_questions_finished"
	)
	_post_game_streak_feedback = GameStreakTrackerScript.construir_feedback(
		previous_streak,
		updated_streak,
		true
	)
	_post_game_flow_state = PostGameFlowControllerScript.construir_estado_flujo_post_juego(
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
	# Cierra el nodo acá; PostGameFlowController evita un segundo cierre si ya no hay partida.
	NodoRuntimeScript.finalizar_mini_juego(get_tree())
	_finalizar_pregunta_normal(_cantidad_de_preguntas())
	_limpiar_estado_local_de_partida_en_pregunta()
	_continuar_despues_de_ensenanza(true)


func _on_flecha_derecha_pressed() -> void:
	_al_presionar_continuar()


func _on_teaching_finished(_timer_finished: bool) -> void:
	_continuar_despues_de_ensenanza(_timer_finished)


func _continuar_despues_de_ensenanza(_timer_finished: bool) -> void:
	_volver_a_escena_mapa()


func _tiene_estado_flujo_post_juego() -> bool:
	return not _post_game_flow_state.is_empty()


func _tomar_estado_flujo_post_juego() -> Dictionary:
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
func _on_jugar_nuevamente_presionado() -> void:
	volver_al_mapa()


func _on_atras_presionado() -> void:
	if _es_juego_de_partida_de_nodo():
		_cancelar_partida_de_nodo_desde_juego()
		return
	volver_al_mapa()






func volver_al_mapa() -> void:
	if _es_juego_de_partida_de_nodo():
		_cancelar_partida_de_nodo_desde_juego()
		return
	if _tiene_estado_flujo_post_juego():
		_on_teaching_finished(false)
		return
	_volver_a_escena_mapa()


func _cancelar_partida_de_nodo_desde_juego() -> void:
	_finalizar_actividad(false)


func _volver_a_escena_mapa() -> void:
	_finalizar_actividad(true)


func _calcular_elapsed_seconds() -> float:
	if _activity_started_msec <= 0:
		push_warning("[TimeTracker] activity_started_msec no inicializado.")
		return -1.0
	var elapsed := float(Time.get_ticks_msec() - _activity_started_msec) / 1000.0
	print("[TimeTracker] elapsed_seconds=", elapsed)
	return elapsed

func _finalizar_actividad(success: bool) -> void:
	_ocultar_continuacion_automatica()
	_limpiar_media_de_pregunta()
	var actividad: Dictionary = NodoRuntimeScript.obtener_actividad_actual(get_tree())
	var activity_id: String = str(actividad.get("id", actividad.get("activity_id", "")))
	var _precision_real: int = NodoRuntimeScript.calcular_precision(get_tree())
	var resultado := {
		"activity_id": activity_id,
		"node_key": _nodo_actual,
		"map_id": SyncApi.resolver_restriccion_para_partida(get_tree(), {}, track_key),
		"success": success,
		"accuracy": clampf(float(_precision_real) / 100.0, 0.0, 1.0),
		"exp": 10,
		"elapsed_seconds": _calcular_elapsed_seconds()
	}
	PostGameFlowControllerScript.finalizar_actividad(get_tree(), resultado)

	
	
