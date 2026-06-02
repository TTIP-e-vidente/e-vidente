extends Control

signal login_completed()
signal play_offline_requested()

const DEMO_BASE_USERNAME := "demo_evidente"
const DEMO_PASSWORD      := "demo_evidente_2026"
const DEMO_NAME          := "Usuario Demo"
const DEMO_AGE           := 18

@onready var _input_username: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/LineEditUsernameOrMail
@onready var _input_password: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/LineEditPassword
@onready var _label_status:   Label    = $CenterContainer/PanelContainer/VBoxContainer/LabelStatus
@onready var _button_login_agus: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonLoginAgus


func _ready() -> void:
	$CenterContainer/PanelContainer/VBoxContainer/ButtonLoginAgus.pressed.connect(
		_on_button_login_agus_pressed
	)
	$CenterContainer/PanelContainer/VBoxContainer/ButtonLogin.pressed.connect(
		_on_button_login_pressed
	)
	$CenterContainer/PanelContainer/VBoxContainer/ButtonRegisterDemo.pressed.connect(
		_on_button_register_demo_pressed
	)
	$CenterContainer/PanelContainer/VBoxContainer/ButtonPlayOffline.pressed.connect(
		_on_button_play_offline_pressed
	)
	$CenterContainer/PanelContainer/VBoxContainer/ButtonMe.pressed.connect(
		_on_button_me_pressed
	)

	# Señales globales de BackendSession — estado asíncrono del Autoload
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


func _actualizar_estado_inicial() -> void:
	if BackendSession.is_logged_in():
		_set_status("Sesión activa: " + BackendSession.get_username())
	else:
		_set_status("Sin sesión")


# ── Botón demo hardcodeado ──────────────────────────────────────────────────

func _on_button_login_agus_pressed() -> void:
	_set_status("Iniciando sesión como agus...")
	await BackendSession.login("agus", "123")
	# La respuesta llega por señales: _on_login_succeeded o _on_login_failed


# ── Botón login manual (oculto — disponible si se reactiva) ──────────────────

func _on_button_login_pressed() -> void:
	var usuario := _input_username.text.strip_edges()
	var clave   := _input_password.text
	if usuario.is_empty() or clave.is_empty():
		_set_status("Completá usuario y contraseña")
		return
	_set_status("Iniciando sesión...")
	# El resultado llega por señales: login_succeeded o login_failed
	await BackendSession.login(usuario, clave)


func _on_button_register_demo_pressed() -> void:
	# Sufijo basado en los últimos 5 dígitos del tiempo unix para ser único
	var suffix   := str(int(Time.get_unix_time_from_system())).right(5)
	var username := DEMO_BASE_USERNAME + "_" + suffix
	var mail     := DEMO_BASE_USERNAME + "_" + suffix + "@evidente.local"
	_set_status("Registrando cuenta demo: " + username)

	var result := await BackendSession.register(
		username, DEMO_NAME, mail, DEMO_PASSWORD, DEMO_AGE
	)

	# Si login_succeeded ya se disparó, no hacer nada más
	if BackendSession.is_logged_in():
		return

	var status_code: int = int(result.get("status", 0))
	if status_code == 409:
		# Usuario ya existe — intentar login directo
		_set_status("Usuario ya existe — intentando login...")
		await BackendSession.login(username, DEMO_PASSWORD)
	elif not result.get("ok", false):
		_set_status(
			"Register falló (%d): %s" % [status_code, str(result.get("error", "error desconocido"))]
		)


func _on_button_me_pressed() -> void:
	if not BackendSession.is_logged_in():
		_set_status("No hay sesión activa")
		return
	_set_status("Consultando /auth/me...")
	var result := await BackendSession.get_me()
	if result.get("ok", false):
		var data: Dictionary = result.get("data", {})
		var uname: String = str(data.get("username", BackendSession.get_username()))
		_set_status("Sesión OK — usuario: " + uname)
	else:
		_set_status("Error /auth/me — status: " + str(result.get("status", 0)))


func _on_button_play_offline_pressed() -> void:
	_set_status("Continuando sin iniciar sesión")
	play_offline_requested.emit()


# ── Señales BackendSession ────────────────────────────────────────────────────

func _on_login_succeeded(user: Dictionary) -> void:
	_set_status("Login OK — " + str(user.get("username", "")))
	login_completed.emit()


func _on_login_failed(_reason: String) -> void:
	_set_status("No se pudo iniciar sesión. Verificá backend.")


func _on_logout_completed() -> void:
	_set_status("Sin sesión")


func _on_session_expired() -> void:
	_set_status("Sesión expirada — volvé a iniciar sesión")


func _on_session_restored(user: Dictionary) -> void:
	var uname := str(user.get("username", BackendSession.get_username()))
	_set_status("Sesión activa: " + uname)


func _on_session_restore_failed(_reason: String) -> void:
	_set_status("Sesión anterior expirada — ingresar nuevamente")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_status(texto: String) -> void:
	print("[Login] ", texto)
	if is_instance_valid(_label_status):
		_label_status.text = texto
