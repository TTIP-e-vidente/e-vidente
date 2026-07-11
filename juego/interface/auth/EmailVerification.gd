extends Control

signal verificacion_completada()
signal verificacion_omitida()

const FlowHelper := preload("res://interface/auth/EmailVerificationFlowHelper.gd")
const FLECHA_ATRAS := preload(
	"res://assets-sistema/interfaz/flecha-ir-para-atras-historias.png"
)
const EMAIL_CHIP_PADDING_X := 28.0
const MAIL_PLACEHOLDER_RUNTIME := "tu casilla de correo"
const MAIL_PLACEHOLDER_ESCENA := "tu_mail@ejemplo.com"
const AYUDA_MAIL_TEXTO := (
	"• Buscá un mail con asunto «Código E-VIDENTE: ######» (no el de bienvenida).\n"
	+ "• Copiá los 6 números del asunto o del bloque dorado del mail.\n"
	+ "• Pegá en el juego: no hace falta agregar espacios.\n"
	+ "• No uses el botón «Copiar código» si abre una página rara: seleccioná el número manualmente.\n"
	+ "• Revisá spam o promociones.\n"
	+ "• Puede tardar 1–2 minutos.\n"
	+ "• Usá «Reenviar código» si pasaron más de 2 minutos.\n"
	+ "• El mail de bienvenida llega recién después de verificar.\n"
	+ "• En desarrollo sin Brevo: el código aparece en los logs de Supabase Edge Functions."
)

@onready var _line_edit_codigo: LineEdit = %LineEditCodigo
@onready var _codigo_input_wrap: Control = %CodigoInputWrap
@onready var _boton_verificar: Button = %BotonVerificar
@onready var _boton_pegar_codigo: Button = %BotonPegarCodigo
@onready var _boton_reenviar: Button = %BotonReenviar
@onready var _boton_omitir: Button = %BotonOmitir
@onready var _boton_ayuda_mail: Button = %BotonAyudaMail
@onready var _boton_volver: Button = %BotonVolver
@onready var _label_ayuda_mail: Label = %LabelAyudaMail
@onready var _label_mensaje: Label = %LabelMensaje
@onready var _label_email: Label = %LabelEmail

var _digit_slots: Array[PanelContainer] = []
var _email_chip: PanelContainer

var _is_loading := false
var _tiempo_cooldown := 0.0
var _requiere_verificacion := false
var _salida_en_curso := false


func _ready() -> void:
	_digit_slots = [
		%DigitSlot0, %DigitSlot1, %DigitSlot2, %DigitSlot3, %DigitSlot4, %DigitSlot5,
	]
	_email_chip = _label_email.get_parent() as PanelContainer

	_boton_verificar.pressed.connect(_on_verificar_presionado)
	_boton_pegar_codigo.pressed.connect(_on_pegar_codigo_presionado)
	_boton_reenviar.pressed.connect(_on_reenviar_presionado)
	_boton_omitir.pressed.connect(_on_omitir_presionado)
	_boton_ayuda_mail.pressed.connect(_on_ayuda_mail_presionado)
	_boton_volver.pressed.connect(_on_volver_presionado)
	_line_edit_codigo.text_submitted.connect(func(_texto: String) -> void: _on_verificar_presionado())
	_line_edit_codigo.text_changed.connect(_on_codigo_text_changed)
	_line_edit_codigo.gui_input.connect(_on_digitos_gui_input)
	if is_instance_valid(_codigo_input_wrap):
		_codigo_input_wrap.gui_input.connect(_on_digitos_gui_input)

	_configurar_entrada_codigo()
	_label_ayuda_mail.visible = false
	_actualizar_casillas_digitos("")
	_configurar_boton_volver()
	_aplicar_configuracion_desde_meta()
	call_deferred("_inicializar_correo_y_estado")
	call_deferred("_enfocar_codigo")


static func _es_mail_placeholder(texto: String) -> bool:
	var limpio := texto.strip_edges()
	return (
		limpio.is_empty()
		or limpio == MAIL_PLACEHOLDER_RUNTIME
		or limpio == MAIL_PLACEHOLDER_ESCENA
	)


func _inicializar_correo_y_estado() -> void:
	var refresh := await ProfileMailSyncHelper.refrescar_perfil_servidor()
	if AuthApi.esta_logueado() and not bool(refresh.get("ok", false)):
		_mostrar_mensaje(
			ProfileMailSyncHelper.mensaje_error(
				{"ok": false, "status": 0, "code": "PROFILE_REFRESH_FAILED"}
			),
			false
		)
	await _sincronizar_estado_desde_servidor()
	if _es_mail_placeholder(_label_email.text):
		_aplicar_mail_desde_evaluacion_meta()
	if _es_mail_placeholder(_label_email.text):
		_mostrar_email_usuario()
	await _asegurar_codigo_pendiente_si_hace_falta()


func _asegurar_codigo_pendiente_si_hace_falta() -> void:
	if AuthApi.mail_esta_verificado() or _is_loading or _salida_en_curso:
		return
	var res := await AuthApi.obtener_estado_verificacion_email()
	if not bool(res.get("ok", false)):
		return
	var data: Variant = res.get("data", {})
	if not data is Dictionary:
		return
	var payload := data as Dictionary
	var verification: Variant = payload.get("verification", {})
	if not verification is Dictionary:
		return
	var estado := verification as Dictionary
	if not bool(estado.get("required", false)):
		return
	if bool(estado.get("has_pending_code", false)):
		return
	if int(estado.get("cooldown_seconds", 0)) > 0:
		return
	var preflight := await ProfileMailSyncHelper.preflight_envio_verificacion()
	if not bool(preflight.get("ok", false)):
		_mostrar_mensaje(str(preflight.get("mensaje", "Mail no disponible ahora.")), false)
		return
	await _solicitar_codigo_automatico()


func _solicitar_codigo_automatico() -> void:
	if _is_loading or _salida_en_curso:
		return
	_establecer_cargando(true)
	_mostrar_mensaje("Enviando código a tu mail...", true)
	var mail_esperado := _label_email.text.strip_edges()
	if _es_mail_placeholder(mail_esperado):
		mail_esperado = str(AuthApi.obtener_usuario_online().get("mail", "")).strip_edges()
	var res := await AuthApi.solicitar_codigo_verificacion(mail_esperado)
	_establecer_cargando(false)
	if res.get("ok", false):
		await _sincronizar_estado_desde_servidor()
	var evaluacion := AuthApi.evaluar_respuesta_verificacion(res)
	var cooldown := int(evaluacion.get("cooldown_seconds", 0))
	if bool(res.get("ok", false)) and cooldown <= 0:
		cooldown = AuthApi.cooldown_verificacion(res, 120)
	if cooldown > 0:
		_iniciar_cooldown(float(cooldown))
	if not str(evaluacion.get("feedback", "")).is_empty():
		_mostrar_mensaje(str(evaluacion.get("feedback", "")), bool(evaluacion.get("feedback_ok", false)))
	elif not res.get("ok", false):
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "No se pudo enviar el código. Tocá «Reenviar código»."),
			false
		)


func _aplicar_configuracion_desde_meta() -> void:
	var root := get_tree().root
	_requiere_verificacion = bool(root.get_meta(FlowHelper.META_OBLIGATORIO, false))
	configurar(_requiere_verificacion)

	var evaluacion: Variant = root.get_meta(FlowHelper.META_EVALUACION, {})
	if evaluacion is Dictionary:
		var ev := evaluacion as Dictionary
		var cooldown := float(ev.get("cooldown_seconds", 0.0))
		if cooldown > 0.0:
			establecer_cooldown_inicial(cooldown)
		var feedback := str(ev.get("feedback", ""))
		if not feedback.is_empty():
			establecer_mensaje_inicial(feedback, bool(ev.get("feedback_ok", true)))
		elif ev.is_empty():
			establecer_mensaje_inicial(
				"Tocá las casillas, escribí o pegá el código de 6 dígitos.",
				true
			)
	_aplicar_mail_desde_evaluacion_meta()


func _aplicar_mail_desde_evaluacion_meta() -> void:
	var root := get_tree().root
	if root == null or not root.has_meta(FlowHelper.META_EVALUACION):
		return
	var evaluacion: Variant = root.get_meta(FlowHelper.META_EVALUACION, {})
	if not evaluacion is Dictionary:
		return
	var target := str((evaluacion as Dictionary).get("target_mail", "")).strip_edges()
	if target.is_empty():
		return

	var server_mail := ProfileMailSyncHelper.obtener_mail_servidor()
	if not server_mail.is_empty():
		if not ProfileMailSyncHelper.mails_coinciden(target, server_mail):
			_establecer_mail_en_ui(server_mail)
			return

	var actual_ui := _label_email.text.strip_edges()
	if (
		not _es_mail_placeholder(actual_ui)
		and not ProfileMailSyncHelper.mails_coinciden(actual_ui, target)
	):
		return

	_establecer_mail_en_ui(target)


func _sincronizar_estado_desde_servidor() -> void:
	if not AuthApi.esta_logueado():
		return
	var res := await AuthApi.obtener_estado_verificacion_email()
	if not res.get("ok", false):
		return
	var data: Variant = res.get("data", {})
	if not data is Dictionary:
		return
	var payload := data as Dictionary
	var mail_mostrar := ProfileMailSyncHelper.resolver_mail_visible(payload)
	if not mail_mostrar.is_empty():
		_establecer_mail_en_ui(mail_mostrar)
	var verification: Variant = payload.get("verification", {})
	if not verification is Dictionary:
		return
	var v := verification as Dictionary
	var cooldown := int(v.get("cooldown_seconds", 0))
	if cooldown > 0:
		_iniciar_cooldown(float(cooldown))
	if v.get("attempts_remaining") != null:
		var remaining := int(v.get("attempts_remaining", 0))
		var max_attempts := int(v.get("max_attempts", 5))
		if remaining >= 0 and remaining < max_attempts:
			_mostrar_mensaje("Te quedan %d intento(s) para este código." % remaining, true)
	var delivery: Variant = v.get("last_verification_delivery", null)
	if delivery is Dictionary:
		var status := str((delivery as Dictionary).get("status", ""))
		if status == "failed":
			var err := str((delivery as Dictionary).get("error_message", "")).strip_edges()
			var msg := "El último envío del código falló. Usá «Reenviar código»."
			if not err.is_empty():
				msg += " (%s)" % err
			_mostrar_mensaje(msg, false)


func _configurar_entrada_codigo() -> void:
	if not is_instance_valid(_line_edit_codigo):
		return
	var fondo_transparente := StyleBoxEmpty.new()
	_line_edit_codigo.add_theme_stylebox_override("normal", fondo_transparente)
	_line_edit_codigo.add_theme_stylebox_override("focus", fondo_transparente)
	_line_edit_codigo.add_theme_stylebox_override("read_only", fondo_transparente)
	_line_edit_codigo.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_line_edit_codigo.add_theme_color_override("font_selected_color", Color(1, 1, 1, 0))
	_line_edit_codigo.add_theme_color_override("font_uneditable_color", Color(1, 1, 1, 0))
	_line_edit_codigo.add_theme_color_override("caret_color", Color(1, 1, 1, 0))
	_line_edit_codigo.placeholder_text = ""
	_line_edit_codigo.context_menu_enabled = false
	_line_edit_codigo.flat = true
	_line_edit_codigo.mouse_filter = Control.MOUSE_FILTER_STOP
	_line_edit_codigo.focus_mode = Control.FOCUS_ALL
	# Puente Web: ver comentario en Login._configurar_campo_tactil. Se usa
	# _codigo_input_wrap como fuente del rect porque es la fila completa de
	# casillas visibles; _line_edit_codigo es un control invisible superpuesto.
	var rect_source: Control = (
		_codigo_input_wrap if is_instance_valid(_codigo_input_wrap) else _line_edit_codigo
	)
	WebTextFieldBridge.adjuntar(_line_edit_codigo, LineEdit.KEYBOARD_TYPE_NUMBER, rect_source)


func _enfocar_codigo() -> void:
	if is_instance_valid(_line_edit_codigo):
		_line_edit_codigo.editable = not _is_loading
		_line_edit_codigo.grab_focus()


func _intentar_pegar_desde_portapapeles() -> void:
	if not is_instance_valid(_line_edit_codigo):
		return
	var clip := DisplayServer.clipboard_get().strip_edges()
	if clip.is_empty():
		# En Safari y en el visor embebido de itch.io el navegador suele
		# bloquear la lectura automática del portapapeles (o vino vacío):
		# avisamos para que no parezca que el pegado "no hizo nada".
		_mostrar_mensaje(
			(
				"No pudimos leer el portapapeles automáticamente (algunos "
				+ "navegadores, como Safari o itch.io, lo bloquean). "
				+ "Escribí el código a mano."
			),
			false
		)
		return
	var digits := _extraer_digitos_codigo(clip)
	if digits.is_empty():
		_mostrar_mensaje(
			"El portapapeles no tiene números. Copiá los 6 dígitos del mail.", false
		)
		return
	_reemplazar_codigo(digits)


func _on_pegar_codigo_presionado() -> void:
	if _is_loading or _salida_en_curso:
		return
	# Tocar un botón es un gesto de usuario válido en cualquier plataforma,
	# a diferencia de Ctrl+V/Cmd+V (no existen en celulares) o del menú
	# contextual de mantener presionado (lo desactivamos para las casillas).
	_intentar_pegar_desde_portapapeles()
	_enfocar_codigo()


func _on_digitos_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			# Enfocar sin call_deferred: en el export Web el teclado táctil del
			# sistema solo abre si grab_focus() corre en la misma respuesta al
			# toque; diferirlo rompe el gesto de usuario dentro del iframe de
			# itch.io.
			_enfocar_codigo()
			_line_edit_codigo.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if _is_loading or _salida_en_curso:
		return
	if not is_instance_valid(_line_edit_codigo) or not _line_edit_codigo.editable:
		return
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if (key_event.ctrl_pressed or key_event.meta_pressed) and key_event.keycode == KEY_V:
		_intentar_pegar_desde_portapapeles()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_BACKSPACE:
		_reemplazar_codigo(_line_edit_codigo.text.substr(0, max(0, _line_edit_codigo.text.length() - 1)))
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_DELETE:
		_reemplazar_codigo("")
		get_viewport().set_input_as_handled()
		return

	var digito := _digito_desde_evento_tecla(key_event)
	if not digito.is_empty():
		_reemplazar_codigo(_line_edit_codigo.text + digito)
		get_viewport().set_input_as_handled()


func establecer_mensaje_inicial(texto: String, es_info: bool = true) -> void:
	_mostrar_mensaje(texto, es_info)


func establecer_cooldown_inicial(segundos: float) -> void:
	_iniciar_cooldown(maxf(segundos, 0.0))


func configurar(requiere_verificacion: bool = false) -> void:
	_requiere_verificacion = requiere_verificacion
	_boton_omitir.visible = not _requiere_verificacion
	if _requiere_verificacion:
		_boton_omitir.disabled = true
	else:
		_configurar_boton_volver()


func _configurar_boton_volver() -> void:
	_boton_volver.text = ""
	_boton_volver.tooltip_text = "Volver"
	_boton_volver.icon = FLECHA_ATRAS
	_boton_volver.flat = true
	_boton_volver.expand_icon = true
	_boton_volver.custom_minimum_size = Vector2(72, 72)


func _on_ayuda_mail_presionado() -> void:
	if not is_instance_valid(_label_ayuda_mail):
		return
	_label_ayuda_mail.visible = not _label_ayuda_mail.visible
	if _label_ayuda_mail.visible:
		_label_ayuda_mail.text = AYUDA_MAIL_TEXTO


func _on_volver_presionado() -> void:
	if _is_loading or _salida_en_curso:
		return
	# La flecha de volver siempre tiene que sacarte de esta pantalla, incluso
	# con verificación obligatoria: "obligatorio" solo bloquea el botón
	# "Omitir" (que finge que ya verificaste), no la salida en sí. El
	# outcome "omitido" con obligatorio=true ya se interpreta como fallo
	# (interpretar_outcome), así que volver nunca te deja pasar sin verificar
	# — solo evita quedar atrapado sin salida.
	_salir_con_outcome("omitido")


func _process(delta: float) -> void:
	if _tiempo_cooldown > 0:
		_tiempo_cooldown -= delta
		if _tiempo_cooldown <= 0:
			_tiempo_cooldown = 0
			_boton_reenviar.disabled = false
			_boton_reenviar.text = "Reenviar código"
		else:
			_boton_reenviar.disabled = true
			_boton_reenviar.text = "Reenviar en %ds" % int(ceil(_tiempo_cooldown))


func _mostrar_email_usuario() -> void:
	var mail := str(AuthApi.obtener_usuario_online().get("mail", "")).strip_edges()
	if mail.is_empty() and BackendSession.hay_verificacion_de_login_pendiente():
		# Login bloqueado por EMAIL_NOT_VERIFIED: sin sesión completa todavía,
		# el mail real vive en la caché de verificación pendiente, no en la
		# de usuario logueado.
		mail = str(
			BackendSession.obtener_usuario_verificacion_pendiente().get("mail", "")
		).strip_edges()
	if mail.is_empty():
		_label_email.text = MAIL_PLACEHOLDER_RUNTIME
		call_deferred("_ajustar_chip_mail")
	else:
		_establecer_mail_en_ui(mail)


func _establecer_mail_en_ui(mail: String) -> void:
	var clean := mail.strip_edges()
	if clean.is_empty():
		return
	_label_email.text = clean
	call_deferred("_ajustar_chip_mail")


func _ajustar_chip_mail() -> void:
	if not is_instance_valid(_label_email):
		return
	var texto := _label_email.text.strip_edges()
	if texto.is_empty():
		return
	var font: Font = _label_email.get_theme_font("font")
	var font_size := _label_email.get_theme_font_size("font_size")
	if font == null:
		return
	var ancho_texto := font.get_string_size(
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size
	).x
	var ancho := ceili(ancho_texto + EMAIL_CHIP_PADDING_X)
	_label_email.custom_minimum_size = Vector2(ancho, 0)
	if is_instance_valid(_email_chip):
		_email_chip.custom_minimum_size = Vector2(ancho, 0)


func _on_codigo_text_changed(new_text: String) -> void:
	var digits := _extraer_digitos_codigo(new_text)
	if digits != new_text:
		_line_edit_codigo.text = digits
		_line_edit_codigo.caret_position = digits.length()
	_actualizar_casillas_digitos(digits)


func _reemplazar_codigo(texto: String) -> void:
	var digits := _extraer_digitos_codigo(texto)
	_line_edit_codigo.text = digits
	_line_edit_codigo.caret_position = digits.length()
	_actualizar_casillas_digitos(digits)


static func _digito_desde_evento_tecla(event: InputEventKey) -> String:
	if event.unicode <= 0:
		return ""
	var caracter := String.chr(event.unicode)
	if caracter >= "0" and caracter <= "9":
		return caracter
	return ""


func _actualizar_casillas_digitos(digits: String) -> void:
	for i in _digit_slots.size():
		var slot := _digit_slots[i]
		if not is_instance_valid(slot):
			continue
		var ch := ""
		if i < digits.length():
			ch = digits[i]
		if slot.has_method("mostrar_caracter"):
			slot.call("mostrar_caracter", ch)


static func _extraer_digitos_codigo(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			out += ch
		if out.length() >= 6:
			break
	return out


func _on_verificar_presionado() -> void:
	if _is_loading or _salida_en_curso:
		return

	var codigo := _extraer_digitos_codigo(_line_edit_codigo.text)
	if codigo.length() != 6:
		_mostrar_mensaje("El código debe tener 6 números (sin espacios).", false)
		return

	_establecer_cargando(true)
	_mostrar_mensaje("Verificando...", true)

	var res := await AuthApi.confirmar_codigo_verificacion(codigo)
	_establecer_cargando(false)

	if res.get("ok", false):
		await BackendSession.refrescar_usuario_en_cache()
		_mostrar_mensaje("¡Mail verificado! Ahora te enviamos el mail de bienvenida.", true)
		await get_tree().create_timer(0.8).timeout
		verificacion_completada.emit()
		await _salir_con_outcome("completado")
	else:
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "Código incorrecto o expirado."),
			false
		)


func _on_reenviar_presionado() -> void:
	if _is_loading or _tiempo_cooldown > 0 or _salida_en_curso:
		return

	_establecer_cargando(true)
	_mostrar_mensaje("Solicitando nuevo código...", true)

	var mail_esperado := _label_email.text.strip_edges()
	if _es_mail_placeholder(mail_esperado):
		mail_esperado = str(AuthApi.obtener_usuario_online().get("mail", "")).strip_edges()
	var res := await AuthApi.solicitar_codigo_verificacion(mail_esperado)
	_establecer_cargando(false)

	if res.get("ok", false):
		await _sincronizar_estado_desde_servidor()

	var evaluacion := AuthApi.evaluar_respuesta_verificacion(res)
	var cooldown := int(evaluacion.get("cooldown_seconds", 0))
	if bool(res.get("ok", false)) and cooldown <= 0:
		cooldown = AuthApi.cooldown_verificacion(res, 120)
	if cooldown > 0:
		_iniciar_cooldown(float(cooldown))
	if not str(evaluacion.get("feedback", "")).is_empty():
		_mostrar_mensaje(str(evaluacion.get("feedback", "")), bool(evaluacion.get("feedback_ok", false)))
	elif not res.get("ok", false):
		_mostrar_mensaje(
			AuthApi.mensaje_verificacion(res, "No se pudo reenviar. Esperá e intentá nuevamente."),
			false
		)


func _on_omitir_presionado() -> void:
	if _is_loading or _requiere_verificacion or _salida_en_curso:
		return
	verificacion_omitida.emit()
	await _salir_con_outcome("omitido")


func _salir_con_outcome(outcome: String) -> void:
	if _salida_en_curso:
		return
	_salida_en_curso = true

	var root := get_tree().root
	root.set_meta(FlowHelper.META_OUTCOME, outcome)
	FlowHelper.complete_waiter(outcome)

	var return_scene := str(
		root.get_meta(FlowHelper.META_RETURN_SCENE, GameSceneRouter.MAIN_MENU_SCENE_PATH)
	).strip_edges()
	if return_scene.is_empty():
		return_scene = GameSceneRouter.MAIN_MENU_SCENE_PATH

	FlowHelper.limpiar_metas_config(root)
	await TransicionEscenas.cambiar_escena_normal(return_scene)


func _iniciar_cooldown(segundos: float) -> void:
	_tiempo_cooldown = maxf(segundos, 0.0)
	_boton_reenviar.disabled = _tiempo_cooldown > 0.0
	if _tiempo_cooldown <= 0.0:
		_boton_reenviar.text = "Reenviar código"


func _establecer_cargando(cargando: bool) -> void:
	_is_loading = cargando
	_boton_verificar.disabled = cargando
	_boton_pegar_codigo.disabled = cargando
	_boton_omitir.disabled = cargando or _requiere_verificacion
	_boton_volver.disabled = cargando or _requiere_verificacion
	_line_edit_codigo.editable = not cargando


func _mostrar_mensaje(texto: String, es_info: bool) -> void:
	_label_mensaje.text = texto
	if es_info:
		_label_mensaje.modulate = MiPaleta.FEEDBACK_OK
	else:
		_label_mensaje.modulate = MiPaleta.FEEDBACK_ERROR


func _on_boton_volver_pressed() -> void:
	GameSceneRouter.MAIN_MENU_SCENE_PATH
