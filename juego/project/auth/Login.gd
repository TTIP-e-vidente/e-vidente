extends Control

enum AuthMode {
	LOGIN,
	REGISTER
}

signal login_completed()
signal play_offline_requested()

@onready var label_title: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelTitle
@onready var label_description: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelDescription
@onready var _input_username: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEditUsernameOrMail
@onready var _input_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEditPassword
@onready var _input_register_name: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEditRegisterName
@onready var _input_register_mail: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEditRegisterMail

@onready var _button_submit: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonSubmit
@onready var _button_switch_mode: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonSwitchMode
@onready var _button_play_offline: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonPlayOffline
@onready var _label_status: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelStatus

var _is_loading := false
var _mode := AuthMode.LOGIN


func _ready() -> void:
	_button_submit.pressed.connect(_on_button_submit_pressed)
	_button_switch_mode.pressed.connect(_on_button_switch_mode_pressed)
	_button_play_offline.pressed.connect(_on_button_play_offline_pressed)
	
	if not _input_password.text_submitted.is_connected(_on_password_submitted):
		_input_password.text_submitted.connect(_on_password_submitted)

	if not BackendSession.login_succeeded.is_connected(_on_login_succeeded):
		BackendSession.login_succeeded.connect(_on_login_succeeded)
	if not BackendSession.login_failed.is_connected(_on_login_failed):
		BackendSession.login_failed.connect(_on_login_failed)
	if not BackendSession.logout_completed.is_connected(_on_logout_completed):
		BackendSession.logout_completed.connect(_on_logout_completed)
	if not BackendSession.session_expired.is_connected(_on_session_expired):
		BackendSession.session_expired.connect(_on_session_expired)
	if not BackendSession.session_restored.is_connected(_on_session_restored):
		BackendSession.session_restored.connect(_on_session_restored)
	if not BackendSession.session_restore_failed.is_connected(_on_session_restore_failed):
		BackendSession.session_restore_failed.connect(_on_session_restore_failed)

	_set_mode(AuthMode.LOGIN)
	_actualizar_estado_inicial()
	_input_username.grab_focus()

func _set_mode(mode: int) -> void:
	_mode = mode

	var is_register := _mode == AuthMode.REGISTER

	label_title.text = "Crear cuenta" if is_register else "Iniciar sesión"
	label_description.text = "Tu progreso se sincronizará con esta cuenta." if is_register else "Ingresá para sincronizar tu progreso."

	_input_register_name.visible = is_register
	_input_register_mail.visible = is_register

	_input_username.placeholder_text = "Usuario" if is_register else "Usuario o mail"

	_button_submit.text = "Crear cuenta" if is_register else "Iniciar sesión"
	_button_switch_mode.text = "Ya tengo cuenta" if is_register else "Crear cuenta"

	_set_status("Sin sesión")


func _actualizar_estado_inicial() -> void:
	if BackendSession.is_logged_in():
		_set_status("Sesion activa: " + BackendSession.get_username())
	else:
		_set_status("Sin sesión")


func _on_button_submit_pressed() -> void:
	if _is_loading:
		return

	if _mode == AuthMode.LOGIN:
		await _submit_login()
	else:
		await _submit_register()

func _submit_login() -> void:
	var username_or_mail := _input_username.text.strip_edges()
	var password := _input_password.text

	if username_or_mail.is_empty() or password.is_empty():
		_set_status("Completá usuario y contraseña.")
		return

	_set_loading(true)
	_set_status("Iniciando sesión...")

	var result := await BackendSession.login(username_or_mail, password)

	if not result.get("ok", false):
		_set_loading(false)
		var status := int(result.get("status", 0))
		if status == 0:
			_set_status("No se pudo conectar. Podés jugar sin iniciar sesión.")
		else:
			_set_status("Usuario o contraseña incorrectos.")
		return

	await _load_account_and_continue()

func _submit_register() -> void:
	var username := _input_username.text.strip_edges()
	var name := _input_register_name.text.strip_edges()
	var mail := _input_register_mail.text.strip_edges()
	var password := _input_password.text

	if username.is_empty() or mail.is_empty() or password.is_empty():
		_set_status("Completá usuario, mail y contraseña.")
		return

	if name.is_empty():
		name = username

	_set_loading(true)
	_set_status("Creando cuenta...")

	var result := await BackendSession.register(username, name, mail, password, 0)

	if not result.get("ok", false):
		_set_loading(false)
		var status := int(result.get("status", 0))
		if status == 0:
			_set_status("No se pudo conectar. Podés jugar sin iniciar sesión.")
		else:
			_set_status("No se pudo crear la cuenta. Probá otro usuario o mail.")
		return

	await _load_account_and_continue()

func _load_account_and_continue() -> void:
	_set_status("Recuperando perfil...")

	var account_result := await BackendSession.load_account_data()

	if not account_result.get("ok", false):
		_set_status("Sesión iniciada, pero no se pudo recuperar progreso. Podés jugar igual.")
		login_completed.emit()
		return

	_set_status("Sesión iniciada.")
	login_completed.emit()

func _on_password_submitted(_new_text: String) -> void:
	_on_button_submit_pressed()

func _on_button_switch_mode_pressed() -> void:
	if _is_loading:
		return

	if _mode == AuthMode.LOGIN:
		_set_mode(AuthMode.REGISTER)
	else:
		_set_mode(AuthMode.LOGIN)


func _on_button_play_offline_pressed() -> void:
	if _is_loading:
		return
	_set_status("Continuando sin iniciar sesion")
	play_offline_requested.emit()


func _on_login_succeeded(user: Dictionary) -> void:
	# No emitir login_completed aca, porque lo emitimos despues de load_account_data
	pass


func _on_login_failed(_reason: String) -> void:
	_set_status("No se pudo iniciar sesion. Verifica backend o credenciales.")
	_set_loading(false)


func _on_logout_completed() -> void:
	_set_status("Sin sesion")


func _on_session_expired() -> void:
	_set_status("Sesion expirada. Inicia sesion nuevamente.")
	_set_loading(false)


func _on_session_restored(user: Dictionary) -> void:
	var username := str(user.get("username", BackendSession.get_username()))
	_set_status("Sesion activa: " + username)


func _on_session_restore_failed(_reason: String) -> void:
	_set_status("Sesion anterior expirada. Inicia sesion nuevamente.")


func _set_loading(value: bool) -> void:
	_is_loading = value
	_button_submit.disabled = value
	_button_switch_mode.disabled = value
	_button_play_offline.disabled = value
	_input_username.editable = not value
	_input_password.editable = not value
	_input_register_name.editable = not value
	_input_register_mail.editable = not value


func _set_status(texto: String) -> void:
	print("[Login] ", texto)
	if is_instance_valid(_label_status):
		_label_status.text = texto
