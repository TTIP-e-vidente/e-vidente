extends Control
class_name OpcionesPalabras
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

# === Dependencia externa ===
const NODO_RUNTIME := preload("res://sistemas/NodoRuntime.gd")

# === Timing ===
const RETURN_TWEEN_DURATION := 0.35   # segundos para que la palabra vuelva a su lugar
const FINISH_DELAY          := 1.5    # segundos antes de llamar finalizar_mini_juego

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
@onready var _prompt_label: Label           = $VBoxContainer/PromptLabel
@onready var _sentence_label: Label         = $VBoxContainer/SentenceLabel
@onready var _options_container: Container  = $VBoxContainer/OptionsContainer
@onready var _feedback_label: Label         = $VBoxContainer/FeedbackLabel

# ConfirmButton es opcional: solo aparece si hay más de 1 blank.
# Si el .tscn no lo tiene, se ignora sin error.
@onready var _confirm_button: Button = $VBoxContainer/ConfirmButton

# ===========================================================================
# ESTADO INTERNO
# ===========================================================================
var _answers: Array[String] = []          # Respuestas correctas en orden del JSON
var _placed: Array[String]  = []          # Respuestas ya colocadas correctamente
var _order_matters: bool    = false       # Si el orden de selección importa
var _sentence_original: String = ""       # Frase con ____ tal como viene del JSON
var _already_finished: bool = false       # Evita doble finalización
var _interaction_locked: bool = false     # Bloquea durante animación de retorno


# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready() -> void:
	_validate_scene_nodes()

	if _confirm_button != null:
		_confirm_button.pressed.connect(_on_confirm_pressed)
		_confirm_button.hide()

	if _feedback_label != null:
		_feedback_label.text = ""

	# Leer actividad de la sesión activa (flujo normal de partida)
	var activity: Dictionary = NODO_RUNTIME.obtener_actividad_actual(get_tree())
	if not activity.is_empty():
		var challenge_data: Dictionary = activity.get("content", activity)
		
		# Si la actividad no tiene 'sentence', es solo la configuración del mapa
		# (por ejemplo: {"type": "word_options", "difficulty": 1}).
		# Usamos el loader para elegir un desafío aleatorio de esa dificultad.
		if not challenge_data.has("sentence"):
			var diff := int(challenge_data.get("difficulty", 1))
			challenge_data = WordOptionsLoader.pick(diff)
			
		setup(challenge_data)


## Verifica que los nodos esperados existan. Loga errores claros si faltan.
func _validate_scene_nodes() -> void:
	if _prompt_label == null:
		push_error("OpcionesPalabras: falta el nodo VBoxContainer/PromptLabel.")
	if _sentence_label == null:
		push_error("OpcionesPalabras: falta el nodo VBoxContainer/SentenceLabel.")
	if _options_container == null:
		push_error("OpcionesPalabras: falta el nodo VBoxContainer/OptionsContainer.")
	if _feedback_label == null:
		push_error("OpcionesPalabras: falta el nodo VBoxContainer/FeedbackLabel.")
	# ConfirmButton no es obligatorio — solo se usa si el .tscn lo incluye.


# ===========================================================================
# API PÚBLICA
# ===========================================================================

## Punto de entrada de la modalidad.
## challenge_data viene de WordOptionsLoader.pick() vía NodoRuntime.
func setup(challenge_data: Dictionary) -> void:
	if not _is_valid_challenge(challenge_data):
		return

	_answers          = _to_string_array(challenge_data.get("answers", []))
	_order_matters    = bool(challenge_data.get("order_matters", false))
	_placed           = []
	_already_finished = false
	_interaction_locked = false
	_sentence_original = str(challenge_data.get("sentence", ""))

	_render(challenge_data)


# ===========================================================================
# RENDERIZADO
# ===========================================================================

## Muestra el desafío completo: prompt, frase y opciones.
func _render(challenge_data: Dictionary) -> void:
	if _prompt_label != null:
		_prompt_label.text = str(challenge_data.get("prompt", ""))
	if _sentence_label != null:
		_sentence_label.text = _sentence_original
	if _feedback_label != null:
		_feedback_label.text = ""
		_feedback_label.add_theme_color_override("font_color", COLOR_NEUTRAL)

	_render_options(challenge_data.get("options", []))
	_update_confirm_button()


## Crea un botón por cada opción. Guarda la posición original para el Tween de retorno.
func _render_options(options: Array) -> void:
	if _options_container == null:
		return
	for child in _options_container.get_children():
		child.queue_free()

	for option_text in options:
		var btn := Button.new()
		btn.text = str(option_text)
		btn.custom_minimum_size = Vector2(120, 48)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Guardar texto original para restaurar al volver
		btn.set_meta("original_text", str(option_text))
		btn.pressed.connect(_on_option_pressed.bind(str(option_text), btn))
		_options_container.add_child(btn)


## Muestra el ConfirmButton solo cuando hay más de 1 blank.
func _update_confirm_button() -> void:
	if _confirm_button == null:
		return
	if _answers.size() > 1:
		_confirm_button.show()
		_confirm_button.disabled = true
	else:
		_confirm_button.hide()


# ===========================================================================
# INTERACCIÓN — Retry Loop
#
# Cada vez que el jugador presiona una opción:
#   1. Se verifica si es correcta para el blank actual (_is_correct_for_current_slot).
#   2. Si CORRECTA  → _place_option_in_slot() → _check_if_completed()
#   3. Si INCORRECTA → _show_error_feedback() → _return_option_to_origin() (shake + unlock)
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
		# INCORRECTO: feedback + shake + el botón vuelve disponible
		_show_error_feedback()
		_return_option_to_origin(btn)


func _on_confirm_pressed() -> void:
	# Con el retry loop slot a slot, ConfirmButton generalmente no es necesario.
	# Se mantiene por compatibilidad en caso de que el .tscn definitivo lo incluya.
	if _already_finished or _interaction_locked:
		return
	if _placed.size() == _answers.size():
		_finish(true)


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
	btn.text = "✓ " + option
	btn.add_theme_color_override("font_color", COLOR_PLACED)
	_update_sentence_display()
	_update_slot_progress()   # Mostrar cuántos blanks quedan


## Verifica si ya se completaron todos los blanks.
func _check_if_completed() -> void:
	if _placed.size() == _answers.size():
		_finish(true)
	else:
		# Todavía faltan blanks: habilitar Confirmar si aplica
		if _confirm_button != null and _confirm_button.visible:
			_confirm_button.disabled = (_placed.size() < _answers.size())


# ===========================================================================
# FEEDBACK DE ERROR — palabra incorrecta vuelve a su lugar
# ===========================================================================

## Muestra feedback de error breve (texto temporal en FeedbackLabel).
func _show_error_feedback() -> void:
	if _feedback_label == null:
		return
	_feedback_label.add_theme_color_override("font_color", COLOR_ERROR)
	_feedback_label.text = "Esa no es. Intentá de nuevo."
	# El texto se limpiará cuando el Tween termine (en _reset_option_state)


## Anima el botón de vuelta a su posición original usando Tween.
## Bloquea la interacción mientras dura la animación.
func _return_option_to_origin(btn: Button) -> void:
	_interaction_locked = true

	# La posición "original" en un FlowContainer/HBoxContainer es la que asignó el container.
	# Para hacer el efecto visual, moveemos el botón fuera del container temporalmente,
	# lo ponemos como overlay, hacemos el Tween, y lo restauramos.
	# Si el .tscn definitivo usa un layout diferente, esta función se adapta al nodo real.
	var origin_pos: Vector2 = btn.global_position

	# Crear un Tween de "shake" como feedback visual inmediato
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Pequeño shake horizontal para feedback de error
	var original_x: float = btn.position.x
	tween.tween_property(btn, "position:x", original_x - 8.0, RETURN_TWEEN_DURATION * 0.25)
	tween.tween_property(btn, "position:x", original_x + 8.0, RETURN_TWEEN_DURATION * 0.25)
	tween.tween_property(btn, "position:x", original_x - 4.0, RETURN_TWEEN_DURATION * 0.25)
	tween.tween_property(btn, "position:x", original_x,       RETURN_TWEEN_DURATION * 0.25)

	await tween.finished
	_reset_option_state(btn)


## Restaura el botón a su estado original después del error.
func _reset_option_state(btn: Button) -> void:
	btn.disabled = false
	btn.text = str(btn.get_meta("original_text", btn.text))
	btn.remove_theme_color_override("font_color")

	if _feedback_label != null:
		_feedback_label.text = ""

	_interaction_locked = false


# ===========================================================================
# ACTUALIZACIÓN DE LA FRASE
# ===========================================================================

## Reemplaza ____ por las palabras ya colocadas.
func _update_sentence_display() -> void:
	if _sentence_label == null:
		return
	var sentence := _sentence_original
	for word in _placed:
		var idx := sentence.find("____")
		if idx != -1:
			sentence = sentence.left(idx) + ("[%s]" % word) + sentence.substr(idx + 4)
	_sentence_label.text = sentence


## Muestra el progreso de slots completados en FeedbackLabel.
## Solo aparece cuando hay más de 1 blank y todavía quedan blanks por completar.
## Usa FeedbackLabel para no requerir un nodo extra en el .tscn.
## El texto se sobreescribe con el feedback de error o éxito cuando corresponde.
func _update_slot_progress() -> void:
	if _feedback_label == null:
		return
	var remaining := _answers.size() - _placed.size()
	if remaining <= 0 or _answers.size() <= 1:
		return   # Sin progreso visible para single-blank o cuando ya terminó
	_feedback_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	_feedback_label.text = "Palabra %d de %d: elegí la siguiente." % [_placed.size(), _answers.size()]


# ===========================================================================
# FINALIZACIÓN — solo cuando todo está correcto
# ===========================================================================

## Completa el mini-juego con éxito.
## Solo se llama cuando _placed.size() == _answers.size().
func _finish(success: bool) -> void:
	if _already_finished:
		return
	_already_finished = true

	_disable_interaction()
	_show_success_feedback()

	await get_tree().create_timer(FINISH_DELAY).timeout

	# Emitir señal si hay listeners (útil para tests o escenas standalone)
	if completed.get_connections().size() > 0:
		completed.emit(success)

	# Reportar al sistema central — score, EXP y progreso se calculan allí
	NODO_RUNTIME.finalizar_mini_juego(get_tree(), Callable(), Callable())


## Muestra feedback de éxito al completar el desafío.
func _show_success_feedback() -> void:
	if _feedback_label == null:
		return
	_feedback_label.add_theme_color_override("font_color", COLOR_OK)
	_feedback_label.text = "¡Correcto!"


## Deshabilita toda interacción al finalizar.
func _disable_interaction() -> void:
	_interaction_locked = true
	if _options_container != null:
		for child in _options_container.get_children():
			var btn := child as Button
			if btn != null:
				btn.disabled = true
	if _confirm_button != null:
		_confirm_button.disabled = true


# ===========================================================================
# HELPERS
# ===========================================================================

## Valida que challenge_data tenga los campos mínimos necesarios.
func _is_valid_challenge(data: Dictionary) -> bool:
	if data.is_empty():
		push_error("OpcionesPalabras.setup: challenge_data está vacío.")
		return false
	for field in ["sentence", "answers", "options"]:
		if not data.has(field):
			push_error("OpcionesPalabras.setup: falta el campo requerido '%s'." % field)
			return false
	if (data.get("answers", []) as Array).is_empty():
		push_error("OpcionesPalabras.setup: 'answers' no puede estar vacío.")
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
