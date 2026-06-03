extends Control

signal login_completed()
signal play_offline_requested()

@onready var _input_username: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEditUsernameOrMail
@onready var _input_password: LineEdit = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LineEditPassword
@onready var _button_login: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonLogin
@onready var _button_play_offline: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonPlayOffline
@onready var _label_status: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LabelStatus

var _is_loading := false


func _ready() -> void:
	_button_login.pressed.connect(_on_button_login_pressed)
	_button_play_offline.pressed.connect(_on_button_play_offline_pressed)

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

	_actualizar_estado_inicial()
	_input_username.grab_focus()


func _actualizar_estado_inicial() -> void:
	if BackendSession.is_logged_in():
		_set_status("Sesion activa: " + BackendSession.get_username())
	else:
		_set_status("Ingresa usuario y contrasena")


func _on_button_login_pressed() -> void:
	if _is_loading:
		return

	_set_loading(true)
	_set_status("Iniciando sesión como Agus...")

	var result := await BackendSession.login("agus", "123")
	if not result.get("ok", false):
		_set_status("No se pudo iniciar sesión. Podés jugar sin iniciar sesión.")
		_set_loading(false)
		return

	_set_status("Recuperando perfil...")
	var load_res := await BackendSession.load_account_data()
	
	if load_res.get("ok", false):
		_set_status("Sesión iniciada como Agus")
		login_completed.emit()
	else:
		_set_status("Sesión iniciada, pero no se pudo recuperar progreso. Podés jugar igual.")
		# Emitimos login_completed de todos modos porque el login fue válido y el backend no debe bloquear jugar
		login_completed.emit()


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
	_button_login.disabled = value
	_button_play_offline.disabled = value
	_input_username.editable = not value
	_input_password.editable = not value


func _set_status(texto: String) -> void:
	print("[Login] ", texto)
	if is_instance_valid(_label_status):
		_label_status.text = texto
