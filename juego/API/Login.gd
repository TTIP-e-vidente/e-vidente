extends Control

enum AuthMode { LOGIN, REGISTER }

signal login_completed()
signal play_offline_requested()

@onready var label_title: Label = $VBoxContainer/LabelTitle
@onready var _input_username: LineEdit = $VBoxContainer/LineEditUsernameOrMail
@onready var _input_password: LineEdit = $VBoxContainer/LineEditPassword
@onready var _input_register_name: LineEdit = $VBoxContainer/LineEditRegisterName
@onready var _input_register_mail: LineEdit = $VBoxContainer/LineEditRegisterMail
@onready var _button_submit: Button = $VBoxContainer/ButtonSubmit
@onready var _button_switch_mode: Button = $VBoxContainer/ButtonSwitchMode
@onready var _button_play_offline: Button = $VBoxContainer/ButtonPlayOffline
@onready var _label_status: Label = $VBoxContainer/LabelStatus

var _is_loading := false
var _mode := AuthMode.LOGIN
var _servidor_ok := false


func _ready() -> void:
	_button_submit.pressed.connect(_on_boton_enviar_presionado)
	_button_switch_mode.pressed.connect(_on_boton_cambiar_modo_presionado)
	_button_play_offline.pressed.connect(_on_boton_jugar_offline_presionado)
	_input_password.text_submitted.connect(_on_clave_enviada)
	BackendSession.session_restored.connect(_on_sesion_restaurada)
	BackendSession.session_restore_failed.connect(_on_fallo_restauracion_sesion)

	_establecer_modo(AuthMode.LOGIN)
	_actualizar_estado_sesion()
	_input_username.grab_focus()
	call_deferred("_verificar_servidor_al_inicio")


func _establecer_modo(mode: AuthMode) -> void:
	_mode = mode
	var is_register := _mode == AuthMode.REGISTER
	label_title.text = "Crear cuenta" if is_register else "Iniciar sesión"
	_input_register_name.visible = is_register
	_input_register_mail.visible = is_register
	_input_username.placeholder_text = "Usuario" if is_register else "Usuario o mail"
	_button_submit.text = "Crear cuenta" if is_register else "Iniciar sesión"
	_button_switch_mode.text = "Ya tengo cuenta" if is_register else "Crear cuenta"
	if not _is_loading and not AuthApi.esta_logueado():
		_establecer_estado("Sin sesión")


func _actualizar_estado_sesion() -> void:
	if AuthApi.esta_logueado():
		_establecer_estado("Sesión activa: " + AuthApi.obtener_usuario())


func _verificar_servidor_al_inicio() -> void:
	if _is_loading or AuthApi.esta_logueado():
		return
	_establecer_estado("Comprobando servidor...")
	var check := await AuthApi.verificar_servidor()
	_servidor_ok = bool(check.get("ok", false))
	if _servidor_ok:
		_establecer_estado("")
		return
	_establecer_estado(AuthApi.mensaje_error(check.get("result", {}), "Servidor no disponible."))


func _on_boton_enviar_presionado() -> void:
	if _is_loading:
		return
	await _enviar_formulario()


func _enviar_formulario() -> void:
	var error_validacion := _validar_formulario()
	if not error_validacion.is_empty():
		_establecer_estado(error_validacion)
		return

	_establecer_cargando(true)
	_establecer_estado("Creando cuenta..." if _mode == AuthMode.REGISTER else "Iniciando sesión...")

	var result: Dictionary
	if _mode == AuthMode.REGISTER:
		var fecha_nacimiento_registro: Variant = null
		# Solo heredar la fecha local si el save no quedó vinculado a otra
		# cuenta online: evita crear la cuenta nueva con datos del usuario previo.
		if SaveManager.obtener_cuenta_online_vinculada().is_empty():
			var fecha_nacimiento_local := SaveManager.obtener_fecha_nacimiento_usuario_actual()
			if not fecha_nacimiento_local.is_empty():
				fecha_nacimiento_registro = fecha_nacimiento_local
		result = await AuthApi.crear_cuenta_completa(
			_input_username.text.strip_edges(),
			_input_password.text,
			_input_register_mail.text.strip_edges(),
			_input_register_name.text.strip_edges(),
			fecha_nacimiento_registro
		)
	else:
		result = await AuthApi.iniciar_sesion_completa(
			_input_username.text.strip_edges(),
			_input_password.text
		)

	_establecer_cargando(false)
	if not result.get("ok", false):
		_establecer_estado(str(result.get("mensaje", "No se pudo completar la operación.")))
		return

	_establecer_estado(str(result.get("mensaje", "Sesión iniciada.")))
	login_completed.emit()


func _validar_formulario() -> String:
	if _mode == AuthMode.REGISTER:
		return AuthApi.validar_campos_registro(
			_input_username.text,
			_input_register_mail.text,
			_input_password.text
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
	_establecer_estado("Sesión activa: " + str(user.get("username", AuthApi.obtener_usuario())))


func _on_fallo_restauracion_sesion(reason: String) -> void:
	_establecer_estado(
		"Sesión anterior expirada.\n"
		+ AuthApi.mensaje_error({"error": reason, "status": 401}, reason)
	)


func _establecer_cargando(value: bool) -> void:
	_is_loading = value
	_button_submit.disabled = value
	_button_switch_mode.disabled = value
	_button_play_offline.disabled = value
	_input_username.editable = not value
	_input_password.editable = not value
	_input_register_name.editable = not value
	_input_register_mail.editable = not value


func _establecer_estado(texto: String) -> void:
	print("[Login] ", texto.replace("\n", " | "))
	if is_instance_valid(_label_status):
		_label_status.text = texto
