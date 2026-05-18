extends Node2D
class_name CompletarPalabra
## Modalidad "Completar con opciones de palabras".
##
## FLUJO INTERNO:
##   _ready()
##     → lee actividad actual vía NodoRuntime
##     → llama setup(challenge_data)
##
##   setup(data)
##     → guarda respuestas esperadas y estado
##     → llama _render()
##
##   _render()
##     → muestra prompt, sentence, opciones como botones
##
##   _on_option_pressed(option, btn)
##     → llama _is_correct_for_current_slot(option)
##     → Si INCORRECTO: _show_error_feedback() + _return_option_to_origin(btn)  ← jugador puede reintentar
##     → Si CORRECTO:   _place_option_in_slot(option, btn) + _check_if_completed()
##
##   _check_if_completed()
##     → si todos los blanks están completos: _finish(true)
##
##   _finish(true)
##     → _show_success_feedback()
##     → espera 1.5s
##     → emite completed(true)
##     → llama NodoRuntime.finalizar_mini_juego()  ← UNA SOLA VEZ
##
## LO QUE ESTA ESCENA NO HACE:
##   - No calcula score, EXP ni progreso.
##   - No hardcodea desafíos.
##   - No toca el JSON directamente.

# === Señales ===
signal completed(success: bool)

const DEBUG_WORD_OPTIONS := false

# === Dependencia externa ===
const NODO_RUNTIME := preload("res://sistemas/NodoRuntime.gd")
const PresentadorContinuarJuegoScript := preload("res://interface/components/ContinuarJuego/PresentadorContinuarJuego.gd")
const PostGameFlowControllerScript := preload("res://niveles/progress/PostGameFlowController.gd")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

# === Timing ===
const RETURN_TWEEN_DURATION := 0.35   # segundos para que la palabra vuelva a su lugar
const FINISH_DELAY          := 1.5    # segundos antes de llamar finalizar_mini_juego

const ENABLE_SCREEN_INTRO := true
const ENABLE_TYPEWRITER := true
const ENABLE_OPTION_STAGGER := true
const ENABLE_BUTTON_HOVER := true
const ENABLE_SUCCESS_TRANSITION := true

const TYPEWRITER_CHAR_DELAY := 0.018
const TYPEWRITER_AFTER_FINISH_DELAY := 0.05
const TYPEWRITER_CURSOR := "▌"

const SCREEN_INTRO_DURATION := 0.30
const OPTION_STAGGER_DELAY := 0.05
const OPTION_FADE_DURATION := 0.20
const OPTION_SLIDE_OFFSET := 16.0

const OPTION_HOVER_SCALE := Vector2(1.06, 1.06)
const OPTION_PRESS_SCALE := Vector2(0.94, 0.94)
const OPTION_CORRECT_SCALE := Vector2(1.12, 1.12)

const WRONG_SHAKE_DISTANCE := 12.0
const WRONG_SHAKE_STEP := 0.05

const SENTENCE_POP_SCALE := Vector2(1.03, 1.03)
const SUCCESS_SENTENCE_SCALE := Vector2(1.06, 1.06)
const SUCCESS_HOLD_SECONDS := 0.65

# === Colores de feedback ===
const COLOR_OK       := Color(0.17, 0.49, 0.28, 1.0)
const COLOR_ERROR    := Color(0.74, 0.18, 0.16, 1.0)
const COLOR_NEUTRAL  := Color(0.18, 0.19, 0.21, 1.0)
const COLOR_PLACED   := Color(0.20, 0.55, 0.35, 1.0)   # verde suave para opción colocada

# ===========================================================================
# NODOS DE LA ESCENA
# El .tscn definitivo debe tener estos nodos con exactamente estos nombres.
# Si alguno falta, _ready() logea un push_error claro.
# ===========================================================================
@onready var titulo_nivel: Label            = $Control/TituloNivel/Label if has_node("Control/TituloNivel/Label") else null
@onready var _prompt_label: Label           = $Control/Escoge
@onready var _sentence_label: RichTextLabel = $Control/Label
@onready var _options_container: Container  = $Control/Container/HBoxContainer
@onready var _continuar_juego: Node         = $Control/ContinuarJuego if has_node("Control/ContinuarJuego") else null

# ===========================================================================
# ESTADO INTERNO
# ===========================================================================
var _answers: Array[String] = []          # Respuestas correctas en orden del JSON
var _placed: Array[String]  = []          # Respuestas ya colocadas correctamente
var _order_matters: bool    = false       # Si el orden de selección importa
var _sentence_template: String = ""       # Frase con ____ tal como viene del JSON
var _already_finished: bool = false       # Evita doble finalización
var _interaction_locked: bool = false     # Bloquea durante animación de retorno
var _is_typewriting: bool = false
var _typewriter_version: int = 0
var _ruta_escena_de_retorno: String = GameSceneRouter.MAP_SCENE_PATH
var _continue_requested: bool = false


# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready() -> void:
	_validate_scene_nodes()

	if _continuar_juego != null:
		_continuar_juego.continuar_solicitado.connect(_al_solicitar_continuar_juego)

	if titulo_nivel != null:
		titulo_nivel.text = "Celiaquía"

	# Leer actividad de la sesión activa (flujo normal de partida)
	var activity: Dictionary = NODO_RUNTIME.obtener_actividad_actual(get_tree())
	if not activity.is_empty():
		var challenge_data: Dictionary = activity.get("content", activity)
		
		# Extraer return_to si existe
		var return_to: String = str(activity.get("return_to", "")).strip_edges()
		if not return_to.is_empty():
			_ruta_escena_de_retorno = return_to

		# Si la actividad no tiene 'sentence', es solo la configuración del mapa
		# (por ejemplo: {"type": "completar_palabra", "difficulty": 1}).
		# Usamos el loader para elegir un desafío aleatorio de esa dificultad.
		if not challenge_data.has("sentence"):
			var diff := int(challenge_data.get("difficulty", 1))
			challenge_data = CargadorCompletar.pick(diff)
			
		setup(challenge_data)
	else:
		push_warning("CompletarPalabra: Abierto en modo standalone (F6). Usando desafío de fallback.")
		_ruta_escena_de_retorno = GameSceneRouter.MAP_SCENE_PATH
		setup(CargadorCompletar.pick(1))


func _debug_log(message: String) -> void:
	if DEBUG_WORD_OPTIONS:
		print("[WordOptions] " + message)


func _on_atrás_pressed() -> void:
	get_tree().change_scene_to_file("res://mapas/MapScene.tscn")


## Verifica que los nodos esperados existan. Loga errores claros si faltan.
func _validate_scene_nodes() -> void:
	if _prompt_label == null:
		push_error("CompletarPalabra: falta el nodo Control/Escoge.")
	if _sentence_label == null:
		push_error("CompletarPalabra: falta el nodo Control/Label.")
	if _options_container == null:
		push_error("CompletarPalabra: falta el nodo Control/Container/HBoxContainer.")


# ===========================================================================
# API PÚBLICA
# ===========================================================================

## Punto de entrada de la modalidad.
## challenge_data viene de CargadorCompletar.pick() vía NodoRuntime.
func setup(challenge_data: Dictionary) -> void:
	if not _is_valid_challenge(challenge_data):
		return

	_answers          = _to_string_array(challenge_data.get("answers", []))
	var options = challenge_data.get("options", [])
	print("[WordOptions] challenge_data=", challenge_data)
	print("[WordOptions] options=", options)
	print("[WordOptions] options count=", options.size())

	_order_matters    = bool(challenge_data.get("order_matters", false))
	_placed           = []
	_already_finished = false
	_interaction_locked = false
	_sentence_template = str(challenge_data.get("sentence", ""))

	_render(challenge_data)


# ===========================================================================
# RENDERIZADO
# ===========================================================================

## Muestra el desafío completo: prompt, frase y opciones.
func _render(challenge_data: Dictionary) -> void:
	if _prompt_label != null:
		_prompt_label.text = str(challenge_data.get("prompt", _prompt_label.text))
	_render_sentence_with_typewriter()

	_render_options(challenge_data.get("options", []))


## Reutiliza y duplica los botones existentes para preservar el estilo visual.
func _render_options(options: Array) -> void:
	if _options_container == null:
		return

	var existing_buttons: Array[Button] = []
	for child in _options_container.get_children():
		if child is Button:
			existing_buttons.append(child)
			
	var prototype_btn: Button = null
	if existing_buttons.size() > 0:
		prototype_btn = existing_buttons[0]
		
	# Crear nuevos botones si faltan
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
			
	# Configurar los botones
	for i in range(existing_buttons.size()):
		var btn: Button = existing_buttons[i]
		if i < options.size():
			btn.show()
			var option_text = str(options[i])
			btn.set_meta("original_text", option_text)
			
			_set_button_text(btn, option_text)
			
			# Configurar señales y estilos
			var connections = btn.pressed.get_connections()
			for conn in connections:
				btn.pressed.disconnect(conn.callable)
				
			btn.pressed.connect(_on_option_pressed.bind(option_text, btn))

			if ENABLE_BUTTON_HOVER:
				# Limpiar conexiones previas de hover
				for conn in btn.button_down.get_connections(): btn.button_down.disconnect(conn.callable)
				for conn in btn.button_up.get_connections(): btn.button_up.disconnect(conn.callable)
				for conn in btn.mouse_entered.get_connections(): btn.mouse_entered.disconnect(conn.callable)
				for conn in btn.mouse_exited.get_connections(): btn.mouse_exited.disconnect(conn.callable)
				
				btn.pivot_offset = btn.size / 2.0
				btn.button_down.connect(func(): if not btn.disabled and not _interaction_locked: _animate_button_scale(btn, OPTION_PRESS_SCALE))
				btn.button_up.connect(func(): if not btn.disabled and not _interaction_locked: _animate_button_scale(btn, OPTION_HOVER_SCALE if btn.is_hovered() else Vector2.ONE))
				btn.mouse_entered.connect(func(): if not btn.disabled and not _interaction_locked: _animate_button_scale(btn, OPTION_HOVER_SCALE))
				btn.mouse_exited.connect(func(): if not btn.disabled and not _interaction_locked: _animate_button_scale(btn, Vector2.ONE))

			# Entrada animada
			if ENABLE_OPTION_STAGGER:
				btn.modulate.a = 0.0
				btn.position.y += OPTION_SLIDE_OFFSET
				var t := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				t.tween_property(btn, "modulate:a", 1.0, OPTION_FADE_DURATION).set_delay(i * OPTION_STAGGER_DELAY)
				t.tween_property(btn, "position:y", btn.position.y - OPTION_SLIDE_OFFSET, OPTION_FADE_DURATION).set_delay(i * OPTION_STAGGER_DELAY)
		else:
			btn.hide()

func _animate_button_scale(btn: Button, target_scale: Vector2) -> void:
	if not is_instance_valid(btn): return
	var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(btn, "scale", target_scale, 0.15)

func _set_button_text(btn: Button, new_text: String) -> void:
	var texto_label = btn.get_node_or_null("TextoOpcion")
	if texto_label != null:
		texto_label.text = new_text
	else:
		btn.text = new_text


# ===========================================================================
# INTERACCIÓN — Retry Loop
#
# Cada vez que el jugador presiona una opción:
#   1. Se verifica si es correcta para el blank actual (_is_correct_for_current_slot).
#   2. Si CORRECTA  → _place_option_in_slot() → _check_if_completed()
#   3. Si INCORRECTA → _return_option_to_origin() (shake + unlock)
#
# El jugador puede reintentar ilimitadas veces. El juego NUNCA termina con error.
# ===========================================================================

func _on_option_pressed(option: String, btn: Button) -> void:
	# Ignorar pulsaciones durante la animación de retorno o después de finalizar
	if _already_finished or _interaction_locked:
		return

	if _is_correct_for_current_slot(option):
		# CORRECTO: colocar en slot y avanzar
		_place_option_in_slot(option, btn)
		_check_if_completed()
	else:
		# INCORRECTO: shake + el botón vuelve disponible
		_return_option_to_origin(btn)


# ===========================================================================
# LÓGICA DE SLOT — el corazón del nuevo game loop
# ===========================================================================

## Devuelve true si la opción es correcta para el blank actual.
## Respeta order_matters.
func _is_correct_for_current_slot(option: String) -> bool:
	var normalized := _normalize(option)
	if _order_matters:
		# Debe coincidir con la respuesta en la posición actual
		var current_index := _placed.size()
		if current_index >= _answers.size():
			return false
		return normalized == _normalize(_answers[current_index])
	else:
		# Puede coincidir con cualquier respuesta que todavía no fue colocada
		for answer in _answers:
			if _normalize(answer) == normalized and not _placed.has(answer):
				return true
		return false


## Marca la opción como colocada y actualiza la frase.
func _place_option_in_slot(option: String, btn: Button) -> void:
	_placed.append(option)
	btn.disabled = true
	_set_button_text(btn, "✓ " + option)
	
	if ENABLE_BUTTON_HOVER:
		_animate_button_scale(btn, OPTION_CORRECT_SCALE)
		var t := create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.2).set_delay(0.15)
	
	var texto_label = btn.get_node_or_null("TextoOpcion")
	if texto_label != null:
		texto_label.add_theme_color_override("font_color", COLOR_PLACED)
	else:
		btn.add_theme_color_override("font_color", COLOR_PLACED)
		
	_render_sentence_direct()
	
	if ENABLE_SUCCESS_TRANSITION and _sentence_label != null:
		_sentence_label.pivot_offset = _sentence_label.size / 2.0
		var t := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(_sentence_label, "scale", SENTENCE_POP_SCALE, 0.15)
		t.tween_property(_sentence_label, "scale", Vector2.ONE, 0.15)


## Verifica si ya se completaron todos los blanks.
func _check_if_completed() -> void:
	if _placed.size() == _answers.size():
		_finish(true)


# ===========================================================================
# FEEDBACK DE ERROR — palabra incorrecta vuelve a su lugar
# ===========================================================================

## Anima el botón de vuelta a su posición original usando Tween.
## Bloquea la interacción mientras dura la animación.
func _return_option_to_origin(btn: Button) -> void:
	_interaction_locked = true

	# Crear un Tween de "shake" como feedback visual inmediato
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Pequeño shake horizontal para feedback de error
	var original_x: float = btn.position.x
	tween.tween_property(btn, "position:x", original_x - WRONG_SHAKE_DISTANCE, WRONG_SHAKE_STEP)
	tween.tween_property(btn, "position:x", original_x + WRONG_SHAKE_DISTANCE, WRONG_SHAKE_STEP)
	tween.tween_property(btn, "position:x", original_x - (WRONG_SHAKE_DISTANCE / 2.0), WRONG_SHAKE_STEP)
	tween.tween_property(btn, "position:x", original_x + (WRONG_SHAKE_DISTANCE / 2.0), WRONG_SHAKE_STEP)
	tween.tween_property(btn, "position:x", original_x, WRONG_SHAKE_STEP)

	await tween.finished
	_reset_option_state(btn)


## Restaura el botón a su estado original después del error.
func _reset_option_state(btn: Button) -> void:
	btn.disabled = false
	var orig_text = str(btn.get_meta("original_text", btn.text))
	_set_button_text(btn, orig_text)

	var texto_label = btn.get_node_or_null("TextoOpcion")
	if texto_label != null:
		texto_label.remove_theme_color_override("font_color")
	else:
		btn.remove_theme_color_override("font_color")

	_interaction_locked = false


# ===========================================================================
# ACTUALIZACIÓN DE LA FRASE Y TYPEWRITER
# ===========================================================================

func _render_sentence_direct() -> void:
	_set_sentence_text(_build_sentence_with_placed_answers())

func _render_sentence_with_typewriter() -> void:
	var rendered := _build_sentence_with_placed_answers()

	if not ENABLE_TYPEWRITER:
		_set_sentence_text(rendered)
		return

	if _placed.size() > 0:
		_set_sentence_text(rendered)
		return

	_start_typewriter(_strip_bbcode(rendered))

func _start_typewriter(text: String) -> void:
	_typewriter_version += 1
	var current_version := _typewriter_version
	_is_typewriting = true

	_set_sentence_text("")

	for i in range(text.length()):
		if current_version != _typewriter_version:
			return

		var cursor_text = text.substr(0, i + 1)
		if i < text.length() - 1:
			cursor_text += TYPEWRITER_CURSOR

		_set_sentence_text(cursor_text)
		await get_tree().create_timer(TYPEWRITER_CHAR_DELAY).timeout

	if current_version != _typewriter_version:
		return

	_is_typewriting = false
	await get_tree().create_timer(TYPEWRITER_AFTER_FINISH_DELAY).timeout

func _set_sentence_text(value: String) -> void:
	if _sentence_label == null:
		return
	if _sentence_label is RichTextLabel:
		_sentence_label.bbcode_enabled = true
		_sentence_label.text = "[center]" + value + "[/center]"
	else:
		_sentence_label.text = _strip_bbcode(value)

func _build_sentence_with_placed_answers() -> String:
	var result := _sentence_template

	for i in range(_answers.size()):
		var replacement := "____"

		if i < _placed.size():
			replacement = "[b]%s[/b]" % str(_placed[i])

		result = _replace_first(result, "____", replacement)

	return result

func _replace_first(text: String, search: String, replacement: String) -> String:
	var idx := text.find(search)
	if idx != -1:
		return text.left(idx) + replacement + text.substr(idx + search.length())
	return text

func _strip_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)


# ===========================================================================
# FINALIZACIÓN — solo cuando todo está correcto
# ===========================================================================

## Completa el mini-juego con éxito.
## Solo se llama cuando _placed.size() == _answers.size().
func _finish(success: bool) -> void:
	if _already_finished:
		return
	
	_already_finished = true
	_interaction_locked = true
	
	_disable_interaction()

	# Transición visual de éxito
	if ENABLE_SUCCESS_TRANSITION and _sentence_label != null:
		var t := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(_sentence_label, "scale", SUCCESS_SENTENCE_SCALE, 0.3)
		await get_tree().create_timer(SUCCESS_HOLD_SECONDS).timeout
	else:
		await get_tree().create_timer(FINISH_DELAY).timeout

	_register_result(success)

	# Emitir señal si hay listeners (útil para tests o escenas standalone)
	if completed.get_connections().size() > 0:
		completed.emit(success)

	_mostrar_continuacion()


## Registra el resultado en el sistema central. La escena no calcula score ni EXP.
func _register_result(success: bool) -> void:
	var global_state: Node = get_tree().root.get_node_or_null("/root/Global")
	if global_state != null and global_state.has_method("registrar_resultado_mini_juego"):
		global_state.call("registrar_resultado_mini_juego", success)


## Muestra la flecha de continuar para que el jugador decida cuándo avanzar.
func _mostrar_continuacion() -> void:
	if _continuar_juego == null:
		# Fallback si no hay presentador
		_continue_or_close_node()
		return
	PresentadorContinuarJuegoScript.mostrar(
		_continuar_juego, 
		NODO_RUNTIME.hay_siguiente_mini_juego(get_tree()), 
		5
	)


## Se ejecuta cuando el jugador presiona la flecha de continuar.
func _al_solicitar_continuar_juego() -> void:
	if _continue_requested:
		return
	
	_continue_requested = true
	_disable_back_button_if_present()
	PresentadorContinuarJuegoScript.ocultar(_continuar_juego)
	_continue_or_close_node()


## Evalúa si hay otro juego pendiente en el Nodo o si debemos cerrar el flujo.
## NodoRuntime decide el progreso internamente.
func _continue_or_close_node() -> void:
	# finalizar_mini_juego avanza la partida internamente y devuelve TRUE si hay siguiente juego.
	var hay_siguiente_juego: bool = NODO_RUNTIME.finalizar_mini_juego(get_tree(), Callable(), Callable())
	
	# Si devolvió FALSE, significa que no hay más juegos en este nodo.
	if not hay_siguiente_juego:
		_go_to_post_game_flow()


## Navega al flujo de post-juego (Pantalla de "Lección Terminada", Racha o Mapa).
## PostGameFlowController es el encargado de rutear usando el _ruta_escena_de_retorno.
func _go_to_post_game_flow() -> void:
	PostGameFlowControllerScript.navigate_to_return_target(get_tree(), _ruta_escena_de_retorno)


## Deshabilita toda interacción al finalizar.
func _disable_interaction() -> void:
	_interaction_locked = true
	_disable_back_button_if_present()
	if _options_container != null:
		for child in _options_container.get_children():
			var btn := child as Button
			if btn != null:
				btn.disabled = true

func _disable_back_button_if_present() -> void:
	var back_button := find_child("Atrás", true, false)
	if back_button == null:
		back_button = find_child("BackButton", true, false)

	if back_button is BaseButton:
		back_button.disabled = true


# ===========================================================================
# HELPERS
# ===========================================================================

## Valida que challenge_data tenga los campos mínimos necesarios.
func _is_valid_challenge(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("CompletarPalabra.setup: challenge_data está vacío.")
		return false
	for field in ["sentence", "answers", "options"]:
		if not data.has(field):
			push_error("CompletarPalabra.setup: falta el campo requerido '%s'." % field)
			return false
	if (data.get("answers", []) as Array).is_empty():
		push_error("CompletarPalabra.setup: 'answers' no puede estar vacío.")
		return false
	return true


## Normaliza texto para comparación: minúsculas y sin espacios extra.
func _normalize(text: String) -> String:
	return text.strip_edges().to_lower()


## Convierte Array de Variant a Array[String].
func _to_string_array(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		result.append(str(item).strip_edges())
	return result
