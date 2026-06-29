extends Control

enum AuthMode { LOGIN, REGISTER }

signal login_completed()
signal play_offline_requested()

signal verificacion_escena_solicitada(es_registro: bool, result: Dictionary)

@onready var label_title: Label = $VBoxContainer/LabelTitle
@onready var _input_username: LineEdit = $VBoxContainer/LineEditUsernameOrMail
@onready var _input_password: LineEdit = $VBoxContainer/LineEditPassword
@onready var _input_register_name: LineEdit = $VBoxContainer/LineEditRegisterName
@onready var _input_register_mail: LineEdit = $VBoxContainer/LineEditRegisterMail
@onready var _input_register_birth_date: LineEdit = $VBoxContainer/LineEditRegisterBirthDate
@onready var _label_register_mail_hint: Label = $VBoxContainer/LabelRegisterMailHint
@onready var _label_register_birth_hint: Label = $VBoxContainer/LabelRegisterBirthHint
@onready var _button_submit: Button = $VBoxContainer/ButtonSubmit
@onready var _button_switch_mode: Button = $VBoxContainer/ButtonSwitchMode
@onready var _button_play_offline: Button = $VBoxContainer/ButtonPlayOffline
@onready var _button_retry: Button = $VBoxContainer/ButtonRetryConnection
@onready var _label_status: Label = $VBoxContainer/LabelStatus

var _is_loading := false
var _verificando_conexion := false
var _mode := AuthMode.LOGIN
var _servidor_ok := false
var _tween_carga: Tween = null


func _ready() -> void:
	_button_submit.pressed.connect(_on_boton_enviar_presionado)
	_button_switch_mode.pressed.connect(_on_boton_cambiar_modo_presionado)
	_button_play_offline.pressed.connect(_on_boton_jugar_offline_presionado)
	_button_retry.pressed.connect(_on_boton_reintentar_conexion_presionado)
	_input_password.text_submitted.connect(_on_clave_enviada)
	BackendSession.session_restored.connect(_on_sesion_restaurada)
	BackendSession.session_restore_failed.connect(_on_fallo_restauracion_sesion)

	_establecer_modo(AuthMode.LOGIN)
	_actualizar_estado_sesion()
	_actualizar_ui_conexion()
	_input_username.grab_focus()
	call_deferred("_verificar_conexion_al_inicio")


func _establecer_modo(mode: AuthMode) -> void:
	_mode = mode
	var is_register := _mode == AuthMode.REGISTER
	label_title.text = "Crear cuenta" if is_register else "Iniciar sesión"
	_input_register_name.visible = is_register
	_input_register_mail.visible = is_register
	_input_register_birth_date.visible = is_register
	_label_register_mail_hint.visible = is_register
	_label_register_birth_hint.visible = is_register
	_input_username.placeholder_text = "Usuario" if is_register else "Usuario o mail"
	_button_submit.text = "Crear cuenta" if is_register else "Iniciar sesión"
	_button_switch_mode.text = "Ya tengo cuenta" if is_register else "Crear cuenta"
	if is_register:
		_precargar_fecha_nacimiento_registro()
	if not _is_loading and not AuthApi.esta_logueado() and _servidor_ok:
		_establecer_estado("Sin sesión")
	_actualizar_ui_conexion()


func _precargar_fecha_nacimiento_registro() -> void:
	if not _input_register_birth_date.text.strip_edges().is_empty():
		return
	if not SaveManager.obtener_cuenta_online_vinculada().is_empty():
		return
	var fecha_local := SaveManager.obtener_fecha_nacimiento_usuario_actual()
	if not fecha_local.is_empty():
		_input_register_birth_date.text = fecha_local


func _actualizar_estado_sesion() -> void:
	if AuthApi.esta_logueado():
		_servidor_ok = true
		_establecer_estado("Sesión activa: " + AuthApi.obtener_usuario())
		_actualizar_ui_conexion()


func _verificar_conexion_al_inicio() -> void:
	await _verificar_conexion(false)


func _on_boton_reintentar_conexion_presionado() -> void:
	if _is_loading or _verificando_conexion:
		return
	await _verificar_conexion(true)


func _verificar_conexion(es_reintento: bool) -> void:
	if _is_loading or AuthApi.esta_logueado():
		return

	_verificando_conexion = true
	_servidor_ok = false
	_actualizar_ui_conexion()

	if es_reintento:
		_establecer_estado("Reintentando conexión a Supabase...")
	else:
		_establecer_estado("Comprobando Supabase y mail...")

	BackendConfig.recargar()
	var check := await AuthApi.verificar_stack()
	_servidor_ok = bool(check.get("ok", false))

	_verificando_conexion = false

	if not _servidor_ok:
		_establecer_estado(
			AuthApi.mensaje_check_conexion(check, "Supabase no disponible."),
			true
		)
		_actualizar_ui_conexion()
		return

	var resumen := AuthApi.resumen_conexion_ok(check)
	var email: Variant = check.get("email", {})
	if email is Dictionary:
		var email_dict := email as Dictionary
		if bool(email_dict.get("enabled", false)) and not bool(email_dict.get("configured", false)):
			if bool(email_dict.get("dev_code_in_logs", false)):
				resumen += "\nModo dev: el OTP aparece en la consola del backend."
			else:
				resumen += "\nAviso: Brevo no configurado — la verificación por mail puede fallar."
	_establecer_estado(resumen)
	_actualizar_ui_conexion()


func _actualizar_ui_conexion() -> void:
	if not is_instance_valid(_button_retry):
		return

	var sesion_activa := AuthApi.esta_logueado()
	var bloquear_login := not _servidor_ok and not sesion_activa

	_button_retry.visible = bloquear_login and not _verificando_conexion
	_button_retry.disabled = _is_loading or _verificando_conexion
	_button_submit.disabled = _is_loading or bloquear_login


func _on_boton_enviar_presionado() -> void:
	if _is_loading:
		return
	if not _servidor_ok and not AuthApi.esta_logueado():
		_establecer_estado(
			"Sin conexión a Supabase.\nLevantá BACKEND (npm run dev) y tocá «Reintentar conexión».",
			true
		)
		_actualizar_ui_conexion()
		return
	await _enviar_formulario()


func _enviar_formulario() -> void:
	var error_validacion := _validar_formulario()
	if not error_validacion.is_empty():
		_establecer_estado(error_validacion, true)
		return

	_establecer_cargando(true)
	_establecer_estado("Creando cuenta..." if _mode == AuthMode.REGISTER else "Iniciando sesión...")

	var result: Dictionary
	if _mode == AuthMode.REGISTER:
		result = await AuthApi.crear_cuenta_completa(
			_input_username.text.strip_edges(),
			_input_password.text,
			_input_register_mail.text.strip_edges(),
			_input_register_name.text.strip_edges(),
			_input_register_birth_date.text.strip_edges(),
			false,
			true
		)
	else:
		result = await AuthApi.iniciar_sesion_completa(
			_input_username.text.strip_edges(),
			_input_password.text
		)

	_establecer_cargando(false)
	if not result.get("ok", false):
		_establecer_estado(str(result.get("mensaje", "No se pudo completar la operación.")), true)
		return

	if _mode == AuthMode.REGISTER:
		var mail_registro := _input_register_mail.text.strip_edges()
		if mail_registro.is_empty():
			_establecer_estado("El mail es obligatorio para crear la cuenta.", true)
			return
		verificacion_escena_solicitada.emit(true, result)
		return
	else:
		if AuthApi.mail_pendiente_verificacion():
			_establecer_estado(
				"Tu mail no está verificado. Te vamos a pedir el código de 6 dígitos.",
				false
			)
			verificacion_escena_solicitada.emit(false, {})
			return
		_establecer_estado(str(result.get("mensaje", "Sesión iniciada.")))

	login_completed.emit()


func _validar_formulario() -> String:
	if _mode == AuthMode.REGISTER:
		return AuthApi.validar_campos_registro(
			_input_username.text,
			_input_register_name.text,
			_input_register_mail.text,
			_input_password.text,
			_input_register_birth_date.text
		)
	return AuthApi.validar_campos_login(_input_username.text, _input_password.text)


func _on_clave_enviada(_new_text: String) -> void:
	_on_boton_enviar_presionado()


func _on_boton_cambiar_modo_presionado() -> void:
	if _is_loading:
		return
	_establecer_modo(AuthMode.LOGIN if _mode == AuthMode.REGISTER else AuthMode.REGISTER)


func _on_boton_jugar_offline_presionado() -> void:
	if _is_loading:
		return
	_establecer_estado("Continuando sin iniciar sesión.\nEl progreso queda solo en este dispositivo.")
	play_offline_requested.emit()


func _on_sesion_restaurada(user: Dictionary) -> void:
	_servidor_ok = true
	_establecer_estado("Sesión activa: " + str(user.get("username", AuthApi.obtener_usuario())))
	_actualizar_ui_conexion()


func _on_fallo_restauracion_sesion(reason: String) -> void:
	_establecer_estado(
		"Sesión anterior expirada.\n"
		+ AuthApi.mensaje_error({"error": reason, "status": 401}, reason),
		true
	)
	call_deferred("_verificar_conexion_al_inicio")


func _establecer_cargando(value: bool) -> void:
	_is_loading = value
	_button_switch_mode.disabled = value
	_button_play_offline.disabled = value
	_input_username.editable = not value
	_input_password.editable = not value
	_input_register_name.editable = not value
	_input_register_mail.editable = not value
	_input_register_birth_date.editable = not value
	_actualizar_ui_conexion()
	if value:
		_iniciar_animacion_carga()
	else:
		_detener_animacion_carga()


func _iniciar_animacion_carga() -> void:
	_detener_animacion_carga()
	if not is_instance_valid(_label_status):
		return
	_tween_carga = create_tween().set_loops()
	_tween_carga.tween_property(_label_status, "modulate:a", 0.4, 0.55)
	_tween_carga.tween_property(_label_status, "modulate:a", 1.0, 0.55)


func _detener_animacion_carga() -> void:
	if _tween_carga != null and _tween_carga.is_valid():
		_tween_carga.kill()
	_tween_carga = null
	if is_instance_valid(_label_status):
		_label_status.modulate.a = 1.0


func _establecer_estado(texto: String, es_error: bool = false) -> void:
	print("[Login] ", texto.replace("\n", " | "))
	if not is_instance_valid(_label_status):
		return
	_label_status.text = texto
	if es_error:
		_label_status.add_theme_color_override("font_color", MiPaleta.FEEDBACK_ERROR)
	elif texto.is_empty():
		_label_status.remove_theme_color_override("font_color")
	else:
		_label_status.add_theme_color_override("font_color", MiPaleta.FEEDBACK_OK)
