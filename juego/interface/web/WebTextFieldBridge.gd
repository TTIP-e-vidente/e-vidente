class_name WebTextFieldBridge
extends Node

const _JS_RUNTIME := """
(function () {
	if (window.__evidenteWebInputReady) return;
	window.__evidenteWebInputReady = true;
	window.__evidenteWebInputs = {};
	window.__evidenteWebInputCreate = function (
		id, type, inputmode, autocomplete, onInput, onFocus, onBlur, onSubmit
	) {
		if (window.__evidenteWebInputs[id]) return;
		var el = document.createElement('input');
		el.type = type || 'text';
		if (inputmode) el.inputMode = inputmode;
		el.autocomplete = autocomplete || 'off';
		el.autocapitalize = 'off';
		el.setAttribute('autocorrect', 'off');
		el.spellcheck = false;
		el.style.position = 'fixed';
		el.style.left = '0px';
		el.style.top = '0px';
		el.style.width = '1px';
		el.style.height = '1px';
		el.style.opacity = '0';
		el.style.border = '0';
		el.style.padding = '0';
		el.style.margin = '0';
		el.style.background = 'transparent';
		el.style.color = 'transparent';
		el.style.caretColor = 'transparent';
		el.style.zIndex = '99999';
		el.style.pointerEvents = 'auto';
		el.style.display = 'none';
		el.style.fontSize = '16px';
		document.body.appendChild(el);
		el.addEventListener('input', function () { onInput(el.value); });
		el.addEventListener('focus', function () { onFocus(); });
		el.addEventListener('blur', function () { onBlur(); });
		el.addEventListener('keydown', function (evt) {
			if (evt.key === 'Enter') { onSubmit(); }
		});
		window.__evidenteWebInputs[id] = el;
	};
	window.__evidenteWebInputSetRect = function (id, left, top, width, height) {
		var el = window.__evidenteWebInputs[id];
		if (!el) return;
		el.style.left = left + 'px';
		el.style.top = top + 'px';
		el.style.width = Math.max(width, 1) + 'px';
		el.style.height = Math.max(height, 1) + 'px';
	};
	window.__evidenteWebInputSetVisible = function (id, visible) {
		var el = window.__evidenteWebInputs[id];
		if (!el) return;
		el.style.display = visible ? 'block' : 'none';
	};
	window.__evidenteWebInputSetValue = function (id, value) {
		var el = window.__evidenteWebInputs[id];
		if (!el || el.value === value) return;
		el.value = value;
	};
	window.__evidenteWebInputBlur = function (id) {
		var el = window.__evidenteWebInputs[id];
		if (el) el.blur();
	};
	window.__evidenteWebInputDestroy = function (id) {
		var el = window.__evidenteWebInputs[id];
		if (el) { el.remove(); delete window.__evidenteWebInputs[id]; }
	};
})();
"""

const _INTERVALO_REPOSICION := 0.1

static var _js_ready := false
static var _contador := 0

var line_edit: LineEdit
var _rect_source: Control
var _overlay_id: String
var _sincronizando := false
var _tiempo_desde_reposicion := 0.0


static var _es_tactil: Variant = null


static func adjuntar(
	campo: LineEdit,
	tipo_teclado: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT,
	rect_source: Control = null
) -> WebTextFieldBridge:
	if OS.get_name() != "Web":
		return null
	if not is_instance_valid(campo):
		return null
	if not _dispositivo_tactil():
		# En notebook/escritorio el enfoque nativo de Godot ya funciona bien:
		# superponer el <input> ahí no aporta nada y puede interferir con el
		# click y la edición normal del campo. Mismo chequeo que usa el motor
		# para decidir si mostrar el teclado virtual (GodotDisplayVK.available).
		return null
	var puente := WebTextFieldBridge.new()
	campo.add_child(puente)
	puente._iniciar(campo, tipo_teclado, rect_source if rect_source != null else campo)
	return puente


static func _dispositivo_tactil() -> bool:
	if _es_tactil == null:
		_es_tactil = bool(JavaScriptBridge.eval("'ontouchstart' in window", true))
	return _es_tactil


static func _mapear_tipo_teclado(tipo: LineEdit.VirtualKeyboardType) -> Array:
	match tipo:
		LineEdit.KEYBOARD_TYPE_NUMBER:
			return ["text", "numeric", "off"]
		LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL:
			return ["text", "decimal", "off"]
		LineEdit.KEYBOARD_TYPE_PHONE:
			return ["tel", "", "tel"]
		LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS:
			return ["email", "", "email"]
		LineEdit.KEYBOARD_TYPE_PASSWORD:
			return ["password", "", "current-password"]
		LineEdit.KEYBOARD_TYPE_URL:
			return ["url", "", "url"]
		_:
			return ["text", "", "off"]


func _iniciar(
	campo: LineEdit, tipo_teclado: LineEdit.VirtualKeyboardType, rect_source: Control
) -> void:
	line_edit = campo
	_rect_source = rect_source
	WebTextFieldBridge._contador += 1
	_overlay_id = "evidente_vk_%d" % WebTextFieldBridge._contador

	_asegurar_js_inicializado()

	var cb_input := JavaScriptBridge.create_callback(_on_js_input)
	var cb_focus := JavaScriptBridge.create_callback(_on_js_focus)
	var cb_blur := JavaScriptBridge.create_callback(_on_js_blur)
	var cb_submit := JavaScriptBridge.create_callback(_on_js_submit)

	var window_obj := JavaScriptBridge.get_interface("window")
	window_obj.set(_overlay_id + "_input", cb_input)
	window_obj.set(_overlay_id + "_focus", cb_focus)
	window_obj.set(_overlay_id + "_blur", cb_blur)
	window_obj.set(_overlay_id + "_submit", cb_submit)

	var tipo_html := _mapear_tipo_teclado(tipo_teclado)
	JavaScriptBridge.eval(
		(
			"window.__evidenteWebInputCreate(%s, %s, %s, %s, "
			+ "window['%s_input'], window['%s_focus'], window['%s_blur'], window['%s_submit']);"
		) % [
			JSON.stringify(_overlay_id), JSON.stringify(tipo_html[0]),
			JSON.stringify(tipo_html[1]), JSON.stringify(tipo_html[2]),
			_overlay_id, _overlay_id, _overlay_id, _overlay_id,
		],
		true
	)

	line_edit.text_changed.connect(_on_line_edit_text_changed)
	_rect_source.resized.connect(_actualizar_posicion)
	_rect_source.visibility_changed.connect(_actualizar_visibilidad)
	get_viewport().size_changed.connect(_actualizar_posicion)

	set_process(true)
	_on_line_edit_text_changed(line_edit.text)
	_actualizar_posicion()
	_actualizar_visibilidad()


func _asegurar_js_inicializado() -> void:
	if WebTextFieldBridge._js_ready:
		return
	WebTextFieldBridge._js_ready = true
	JavaScriptBridge.eval(_JS_RUNTIME, true)


func _process(delta: float) -> void:
	# Reposicionar cada frame sería redundante: el layout no cambia tan
	# seguido. Se recalcula cada _INTERVALO_REPOSICION para cubrir animaciones,
	# rotación de pantalla y el resize que dispara el teclado nativo al abrir.
	_tiempo_desde_reposicion += delta
	if _tiempo_desde_reposicion >= _INTERVALO_REPOSICION:
		_tiempo_desde_reposicion = 0.0
		_actualizar_posicion()


func _actualizar_posicion() -> void:
	if not is_instance_valid(line_edit) or not is_instance_valid(_rect_source):
		return
	var canvas_rect_json: Variant = JavaScriptBridge.eval(
		"JSON.stringify(document.querySelector('canvas').getBoundingClientRect())", true
	)
	if canvas_rect_json == null:
		return
	var parsed: Variant = JSON.parse_string(str(canvas_rect_json))
	if not parsed is Dictionary:
		return
	var rect_dom := parsed as Dictionary
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var dom_width := float(rect_dom.get("width", 0.0))
	var dom_height := float(rect_dom.get("height", 0.0))
	if dom_width <= 0.0 or dom_height <= 0.0:
		return
	var escala_x := dom_width / viewport_size.x
	var escala_y := dom_height / viewport_size.y
	var global_rect := _rect_source.get_global_rect()
	var left := float(rect_dom.get("left", 0.0)) + global_rect.position.x * escala_x
	var top := float(rect_dom.get("top", 0.0)) + global_rect.position.y * escala_y
	var width := global_rect.size.x * escala_x
	var height := global_rect.size.y * escala_y
	JavaScriptBridge.eval(
		"window.__evidenteWebInputSetRect(%s, %f, %f, %f, %f);" % [
			JSON.stringify(_overlay_id), left, top, width, height
		],
		true
	)


func _actualizar_visibilidad() -> void:
	if not is_instance_valid(_rect_source):
		return
	var visible_efectivo := _rect_source.is_visible_in_tree()
	JavaScriptBridge.eval(
		"window.__evidenteWebInputSetVisible(%s, %s);" % [
			JSON.stringify(_overlay_id), "true" if visible_efectivo else "false"
		],
		true
	)


func _on_line_edit_text_changed(nuevo_texto: String) -> void:
	if _sincronizando:
		return
	JavaScriptBridge.eval(
		"window.__evidenteWebInputSetValue(%s, %s);" % [
			JSON.stringify(_overlay_id), JSON.stringify(nuevo_texto)
		],
		true
	)


func _on_js_input(args: Array) -> void:
	if args.is_empty() or not is_instance_valid(line_edit):
		return
	_sincronizando = true
	line_edit.text = str(args[0])
	line_edit.caret_column = line_edit.text.length()
	_sincronizando = false
	line_edit.text_changed.emit(line_edit.text)


func _on_js_focus(_args: Array) -> void:
	if is_instance_valid(line_edit):
		line_edit.grab_focus()


func _on_js_blur(_args: Array) -> void:
	if is_instance_valid(line_edit) and line_edit.has_focus():
		line_edit.release_focus()


func _on_js_submit(_args: Array) -> void:
	if is_instance_valid(line_edit):
		line_edit.text_submitted.emit(line_edit.text)


func _exit_tree() -> void:
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval("window.__evidenteWebInputDestroy(%s);" % JSON.stringify(_overlay_id), true)
