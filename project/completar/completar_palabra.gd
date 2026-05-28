extends Node2D
class_name CompletarPalabra

signal completed(success: bool)

const DEBUG_WORD_OPTIONS := false
const DEFAULT_SCREEN_TITLE := "Escogé la palabra que falta"

const NODO_RUNTIME := preload("res://sistemas/NodoRuntime.gd")
const PresentadorContinuarJuegoScript := preload(
	"res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd"
)
const PostGameFlowControllerScript := preload("res://niveles/progress/PostGameFlowController.gd")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ContextoSesionDeJuegoScript := preload("res://niveles/progress/ContextoSesionDeJuego.gd")

const RETURN_TWEEN_DURATION := 0.35
const FINISH_DELAY          := 1.5
const ENABLE_SCREEN_INTRO := true
const ENABLE_TYPEWRITER := true
const ENABLE_OPTION_STAGGER := false
const ENABLE_BUTTON_HOVER := true
const ENABLE_SUCCESS_TRANSITION := true

@export_group("Type Effect")
@export_range(0.01, 0.08, 0.005) var character_delay: float = 0.035
@export_range(0.0, 0.5, 0.05) var initial_delay: float = 0.15
@export_range(0.0, 0.5, 0.05) var typewriter_after_finish_delay: float = 0.10
@export var allow_skip: bool = true

@export_group("Opciones")
@export_range(0.05, 0.4, 0.01) var option_stagger_delay: float = 0.12
@export_range(0.1, 0.5, 0.05) var option_fade_duration: float = 0.30
@export_range(4.0, 30.0, 2.0) var option_slide_offset: float = 10.0

@export_group("Hover & Press")
@export var option_hover_scale: Vector2 = Vector2(1.025, 1.025)
@export var option_press_scale: Vector2 = Vector2(0.975, 0.975)
const OPTION_CORRECT_SCALE := Vector2(1.12, 1.12)

const WRONG_SHAKE_DISTANCE := 12.0
const WRONG_SHAKE_STEP := 0.05

const SENTENCE_POP_SCALE := Vector2(1.03, 1.03)
const SUCCESS_SENTENCE_SCALE := Vector2(1.06, 1.06)
const SUCCESS_HOLD_SECONDS := 0.65

const COLOR_PLACED   := Color(0.20, 0.55, 0.35, 1.0)

@onready var titulo_nivel: Label = (
	$Control/TituloNivel/Label if has_node("Control/TituloNivel/Label") else null
)
@onready var _prompt_label: Label           = $Control/Escoge
@onready var _sentence_label: RichTextLabel = $Control/Label
@onready var _options_container: Container  = $Control/HBoxContainer
@onready var _continuar_juego: Node = (
	$Control/ContinuarJuego if has_node("Control/ContinuarJuego") else null
)

var _answers: Array[String] = []
var _placed: Array[String]  = []
var _order_matters: bool    = false
var _sentence_template: String = ""
var _already_finished: bool = false
var _interaction_locked: bool = false
var _typewriter: TypewriterEffect = TypewriterEffect.new()
var _ruta_escena_de_retorno: String = GameSceneRouter.MAP_SCENE_PATH
var _continue_requested: bool = false

func _ready() -> void:
	_configurar_typewriter()
	_validar_nodos_escena()

	if _continuar_juego != null:
		_continuar_juego.continuar_solicitado.connect(_al_solicitar_continuar_juego)

	if titulo_nivel != null:
		titulo_nivel.text = "Celiaquía"

	var activity: Dictionary = NODO_RUNTIME.obtener_actividad_actual(get_tree())
	if not activity.is_empty():
		var challenge_data: Dictionary = activity.get("content", activity)

		var return_to: String = str(activity.get("return_to", "")).strip_edges()
		if not return_to.is_empty():
			_ruta_escena_de_retorno = return_to

		if not challenge_data.has("sentence") and not challenge_data.has("prompt"):
			var diff: int = int(challenge_data.get("difficulty", 1))
			challenge_data = CargadorCompletar.elegir(diff)

		configurar(challenge_data)
	else:
		push_warning(
			"CompletarPalabra: Abierto en modo standalone (F6). Usando desafío de fallback."
		)
		_ruta_escena_de_retorno = GameSceneRouter.MAP_SCENE_PATH
		configurar(CargadorCompletar.elegir(1))

func _input(event: InputEvent) -> void:
	if not _typewriter.esta_escribiendo():
		return
	if event is InputEventMouseButton and event.pressed:
		_typewriter.solicitar_salto()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_typewriter.solicitar_salto()
		get_viewport().set_input_as_handled()

func _al_presionar_atras() -> void:
	await TransicionEscenas.change_normal_scene("res://mapas/MapScene.tscn")

func _validar_nodos_escena() -> void:
	if _prompt_label == null:
		push_error("CompletarPalabra: falta el nodo Control/Escoge.")
	if _sentence_label == null:
		push_error("CompletarPalabra: falta el nodo Control/Label.")
	if _options_container == null:
		push_error("CompletarPalabra: falta el nodo Control/Container/HBoxContainer.")

func configurar(challenge_data: Dictionary) -> void:
	if not _es_desafio_valido(challenge_data):
		return

	_answers          = _a_array_texto(
		challenge_data.get("correct_answers", challenge_data.get("answers", []))
	)

	_order_matters    = bool(challenge_data.get("order_matters", false))
	_placed           = []
	_already_finished = false
	_interaction_locked = false
	_sentence_template = str(challenge_data.get("prompt", challenge_data.get("sentence", "")))

	_renderizar(challenge_data)

func _renderizar(challenge_data: Dictionary) -> void:
	if _prompt_label != null:
		_prompt_label.text = _titulo_desde_datos(challenge_data)
	_renderizar_async(challenge_data)

func _renderizar_async(challenge_data: Dictionary) -> void:
	var options: Array = challenge_data.get("choices", challenge_data.get("options", []))
	var active_buttons := _preparar_botones_opciones(options)
	await _renderizar_frase_con_typewriter()
	await _revelar_textos_opciones(active_buttons)

func _titulo_desde_datos(challenge_data: Dictionary) -> String:
	var screen_title: String = str(
		challenge_data.get("screen_title", DEFAULT_SCREEN_TITLE)
	).strip_edges()
	if screen_title.is_empty():
		return DEFAULT_SCREEN_TITLE
	return screen_title

func _preparar_botones_opciones(options: Array) -> Array[Button]:
	var active_buttons: Array[Button] = []
	if _options_container == null:
		return active_buttons
	_interaction_locked = true

	var existing_buttons: Array[Button] = []
	for child in _options_container.get_children():
		if child is Button:
			existing_buttons.append(child)

	var prototype_btn: Button = null
	if existing_buttons.size() > 0:
		prototype_btn = existing_buttons[0]

	while existing_buttons.size() < options.size():
		if prototype_btn != null:
			var new_btn = prototype_btn.duplicate()
			_options_container.add_child(new_btn)
			existing_buttons.append(new_btn)
		else:
			var new_btn = Button.new()
			_options_container.add_child(new_btn)
			existing_buttons.append(new_btn)
			prototype_btn = new_btn

	for i in range(existing_buttons.size()):
		var btn: Button = existing_buttons[i]
		if i < options.size():
			var option_text := str(options[i])
			btn.set_meta("original_text", option_text)

			var texto_label: Label = btn.get_node_or_null("TextoOpcion")
			if texto_label != null:
				texto_label.text = option_text
				texto_label.modulate.a = 0.0
			else:
				btn.text = ""
				btn.set_meta("pending_text", option_text)

			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn.callable)
			btn.pressed.connect(_al_seleccionar_opcion.bind(option_text, btn))

			if ENABLE_BUTTON_HOVER:
				for conn in btn.button_down.get_connections():
					btn.button_down.disconnect(conn.callable)
				for conn in btn.button_up.get_connections():
					btn.button_up.disconnect(conn.callable)
				for conn in btn.mouse_entered.get_connections():
					btn.mouse_entered.disconnect(conn.callable)
				for conn in btn.mouse_exited.get_connections():
					btn.mouse_exited.disconnect(conn.callable)

				btn.pivot_offset = btn.size / 2.0
				btn.button_down.connect(_al_presionar_boton_opcion.bind(btn))
				btn.button_up.connect(_al_soltar_boton_opcion.bind(btn))
				btn.mouse_entered.connect(_al_entrar_raton_opcion.bind(btn))
				btn.mouse_exited.connect(_al_salir_raton_opcion.bind(btn))

			btn.modulate.a = 1.0
			btn.scale = Vector2.ONE
			btn.disabled = false
			btn.show()
			active_buttons.append(btn)
		else:
			btn.hide()

	return active_buttons

func _revelar_textos_opciones(active_buttons: Array[Button]) -> void:
	if active_buttons.is_empty():
		return

	_interaction_locked = true

	var reveal_tween := (
		create_tween()
		.set_parallel(true)
		.set_ease(Tween.EASE_OUT)
		.set_trans(Tween.TRANS_SINE)
	)

	for i in range(active_buttons.size()):
		var btn: Button = active_buttons[i]
		if not is_instance_valid(btn):
			continue
		var delay: float = i * option_stagger_delay
		var texto_label: Label = btn.get_node_or_null("TextoOpcion")
		if texto_label != null:
			var text_tween := reveal_tween.tween_property(
				texto_label,
				"modulate:a",
				1.0,
				option_fade_duration
			)
			text_tween.set_delay(delay)
		else:
			btn.text = str(btn.get_meta("pending_text", ""))
			btn.modulate.a = 0.0
			reveal_tween.tween_property(
					btn, "modulate:a", 1.0, option_fade_duration).set_delay(delay)

	await reveal_tween.finished

	for btn in active_buttons:
		if is_instance_valid(btn) and not _already_finished:
			btn.disabled = false
	_interaction_locked = false

func _revelar_opciones_escalonadas(all_buttons: Array[Button], active_count: int) -> void:
	_interaction_locked = true

	var active_buttons: Array[Button] = []
	for i in range(active_count):
		if i < all_buttons.size():
			active_buttons.append(all_buttons[i])

	var reveal_tween := (
		create_tween()
		.set_parallel(true)
		.set_ease(Tween.EASE_OUT)
		.set_trans(Tween.TRANS_SINE)
	)

	for i in range(active_buttons.size()):
		var btn: Button = active_buttons[i]
		if not is_instance_valid(btn):
			continue
		var delay: float = i * option_stagger_delay
		reveal_tween.tween_property(btn, "modulate:a", 1.0, option_fade_duration).set_delay(delay)
		reveal_tween.tween_property(
			btn, "scale", Vector2.ONE, option_fade_duration).set_delay(delay)
		var position_tween := reveal_tween.tween_property(
			btn,
			"position:y",
			btn.position.y - option_slide_offset,
			option_fade_duration
		)
		position_tween.set_delay(delay)

	await reveal_tween.finished
	for btn in active_buttons:
		if is_instance_valid(btn) and not _already_finished:
			btn.disabled = false
	_interaction_locked = false

func _animar_escala_boton(btn: Button, target_scale: Vector2) -> void:
	if not is_instance_valid(btn):
		return
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(btn, "scale", target_scale, 0.15)

func _al_presionar_boton_opcion(btn: Button) -> void:
	if not btn.disabled and not _interaction_locked:
		_animar_escala_boton(btn, option_press_scale)

func _al_soltar_boton_opcion(btn: Button) -> void:
	if btn.disabled or _interaction_locked:
		return
	var target_scale := option_hover_scale if btn.is_hovered() else Vector2.ONE
	_animar_escala_boton(btn, target_scale)

func _al_entrar_raton_opcion(btn: Button) -> void:
	if not btn.disabled and not _interaction_locked:
		_animar_escala_boton(btn, option_hover_scale)

func _al_salir_raton_opcion(btn: Button) -> void:
	if not btn.disabled and not _interaction_locked:
		_animar_escala_boton(btn, Vector2.ONE)

func _asignar_texto_boton(btn: Button, new_text: String) -> void:
	var texto_label = btn.get_node_or_null("TextoOpcion")
	if texto_label != null:
		texto_label.text = new_text
	else:
		btn.text = new_text

func _al_seleccionar_opcion(option: String, btn: Button) -> void:
	if _already_finished or _interaction_locked:
		return

	if _es_correcta_para_slot_actual(option):
		_colocar_opcion_en_slot(option, btn)
		_verificar_si_completado()
	else:
		_devolver_opcion_al_origen(btn)

func _es_correcta_para_slot_actual(option: String) -> bool:
	var normalized := _normalizar(option)
	if _order_matters:
		var current_index := _placed.size()
		if current_index >= _answers.size():
			return false
		return normalized == _normalizar(_answers[current_index])

	for answer in _answers:
		if _normalizar(answer) == normalized and not _placed.has(answer):
			return true
	return false

func _colocar_opcion_en_slot(option: String, btn: Button) -> void:
	_placed.append(option)
	btn.disabled = true
	_asignar_texto_boton(btn, "✓ " + option)

	if ENABLE_BUTTON_HOVER:
		_animar_escala_boton(btn, OPTION_CORRECT_SCALE)
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.2).set_delay(0.15)

	var texto_label = btn.get_node_or_null("TextoOpcion")
	if texto_label != null:
		texto_label.add_theme_color_override("font_color", COLOR_PLACED)
	else:
		btn.add_theme_color_override("font_color", COLOR_PLACED)

	_renderizar_frase_directa()

	if ENABLE_SUCCESS_TRANSITION and _sentence_label != null:
		_sentence_label.pivot_offset = _sentence_label.size / 2.0
		var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(_sentence_label, "scale", SENTENCE_POP_SCALE, 0.15)
		t.tween_property(_sentence_label, "scale", Vector2.ONE, 0.15)

func _verificar_si_completado() -> void:
	if _placed.size() == _answers.size():
		_finalizar(true)

func _devolver_opcion_al_origen(btn: Button) -> void:
	_interaction_locked = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	var original_x: float = btn.position.x
	tween.tween_property(btn, "position:x", original_x - WRONG_SHAKE_DISTANCE, WRONG_SHAKE_STEP)
	tween.tween_property(btn, "position:x", original_x + WRONG_SHAKE_DISTANCE, WRONG_SHAKE_STEP)
	tween.tween_property(
		btn,
		"position:x",
		original_x - (WRONG_SHAKE_DISTANCE / 2.0),
		WRONG_SHAKE_STEP
	)
	tween.tween_property(
		btn,
		"position:x",
		original_x + (WRONG_SHAKE_DISTANCE / 2.0),
		WRONG_SHAKE_STEP
	)
	tween.tween_property(btn, "position:x", original_x, WRONG_SHAKE_STEP)

	await tween.finished
	_restablecer_estado_opcion(btn)

func _restablecer_estado_opcion(btn: Button) -> void:
	btn.disabled = false
	var orig_text = str(btn.get_meta("original_text", btn.text))
	_asignar_texto_boton(btn, orig_text)

	var texto_label = btn.get_node_or_null("TextoOpcion")
	if texto_label != null:
		texto_label.remove_theme_color_override("font_color")
	else:
		btn.remove_theme_color_override("font_color")

	_interaction_locked = false

func _renderizar_frase_directa() -> void:
	_asignar_texto_frase(_construir_frase_con_respuestas())

func _renderizar_frase_con_typewriter() -> void:
	var rendered := _construir_frase_con_respuestas()

	if not ENABLE_TYPEWRITER:
		_asignar_texto_frase(rendered)
		return

	if _placed.size() > 0:
		_asignar_texto_frase(rendered)
		return

	await _typewriter.iniciar(
		self, func(t: String): _asignar_texto_frase(t), _limpiar_bbcode(rendered))

func _configurar_typewriter() -> void:
	_typewriter.character_delay = character_delay
	_typewriter.initial_delay = initial_delay
	_typewriter.after_finish_delay = typewriter_after_finish_delay
	_typewriter.allow_skip = allow_skip

func _asignar_texto_frase(value: String) -> void:
	if _sentence_label == null:
		return
	if _sentence_label is RichTextLabel:
		_sentence_label.bbcode_enabled = true
		_sentence_label.text = "[center]" + value + "[/center]"
	else:
		_sentence_label.text = _limpiar_bbcode(value)

func _construir_frase_con_respuestas() -> String:
	var result := _sentence_template

	for i in range(_answers.size()):
		var replacement := "____"

		if i < _placed.size():
			replacement = "[b]%s[/b]" % str(_placed[i])

		result = _reemplazar_primero(result, "____", replacement)

	return result

func _reemplazar_primero(text: String, search: String, replacement: String) -> String:
	var idx := text.find(search)
	if idx != -1:
		return text.left(idx) + replacement + text.substr(idx + search.length())
	return text

func _limpiar_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)

func _finalizar(success: bool) -> void:
	if _already_finished:
		return

	_already_finished = true
	_interaction_locked = true

	_deshabilitar_interaccion()

	if ENABLE_SUCCESS_TRANSITION and _sentence_label != null:
		var t := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(_sentence_label, "scale", SUCCESS_SENTENCE_SCALE, 0.3)
		await get_tree().create_timer(SUCCESS_HOLD_SECONDS).timeout
	else:
		await get_tree().create_timer(FINISH_DELAY).timeout

	_registrar_resultado(success)

	if completed.get_connections().size() > 0:
		completed.emit(success)

	_mostrar_continuacion()

func _registrar_resultado(success: bool) -> void:
	var global_state: Node = ContextoSesionDeJuegoScript.obtener_global()
	if global_state != null and global_state.has_method("registrar_resultado_mini_juego"):
		global_state.call("registrar_resultado_mini_juego", success)

func _mostrar_continuacion() -> void:
	if _continuar_juego == null:
		_continuar_o_cerrar_nodo()
		return
	PresentadorContinuarJuegoScript.mostrar(
		_continuar_juego,
		NODO_RUNTIME.hay_siguiente_mini_juego(get_tree()),
		5
	)

func _al_solicitar_continuar_juego() -> void:
	if _continue_requested:
		return

	_continue_requested = true
	_deshabilitar_boton_atras()
	PresentadorContinuarJuegoScript.ocultar(_continuar_juego)
	_continuar_o_cerrar_nodo()

func _continuar_o_cerrar_nodo() -> void:
	var hay_siguiente_juego: bool = NODO_RUNTIME.finalizar_mini_juego(
		get_tree(),
		Callable(),
		Callable()
	)

	if not hay_siguiente_juego:
		_ir_a_flujo_post_juego()

func _ir_a_flujo_post_juego() -> void:
	PostGameFlowControllerScript.navigate_to_return_target(get_tree(), _ruta_escena_de_retorno)

func _deshabilitar_interaccion() -> void:
	_interaction_locked = true
	_deshabilitar_boton_atras()
	if _options_container != null:
		for child in _options_container.get_children():
			var btn := child as Button
			if btn != null:
				btn.disabled = true

func _deshabilitar_boton_atras() -> void:
	var back_button := find_child("Atrás", true, false)
	if back_button == null:
		back_button = find_child("BackButton", true, false)

	if back_button is BaseButton:
		back_button.disabled = true

func _es_desafio_valido(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("CompletarPalabra.configurar: challenge_data está vacío.")
		return false
	var prompt: String = str(data.get("prompt", data.get("sentence", ""))).strip_edges()
	var answers_raw: Variant = data.get("correct_answers", data.get("answers", []))
	var choices_raw: Variant = data.get("choices", data.get("options", []))
	if (
		not prompt.is_empty()
		and answers_raw is Array
		and not (answers_raw as Array).is_empty()
		and choices_raw is Array
		and not (choices_raw as Array).is_empty()
	):
		return true
	for field in ["sentence", "answers", "options"]:
		if not data.has(field):
			push_error("CompletarPalabra.configurar: falta el campo requerido '%s'." % field)
			return false
	if (data.get("answers", []) as Array).is_empty():
		push_error("CompletarPalabra.configurar: 'answers' no puede estar vacío.")
		return false
	return true

func _normalizar(text: String) -> String:
	return text.strip_edges().to_lower()

func _a_array_texto(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		result.append(str(item).strip_edges())
	return result