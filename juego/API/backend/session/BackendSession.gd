## BackendSession: fachada sesión/backend
## Fachada principal entre Godot y el backend.
## Responsabilidad:
## - Login / registro / logout.
## - Guardar token.
## - Recuperar perfil/progreso.
## - Exponer save_progress().
## - Emitir señales de sync.
## No debe:
## - Usar HTTPRequest directo.
## - Tocar reglas de gameplay.
extends Node

# ── Señales públicas ────────────────────────────────────────────────────────

## Reenviadas desde ProgressSyncService
signal sync_started()
signal sync_succeeded(progress: Dictionary)
signal sync_failed(reason: String)
signal pending_sync_started(count: int)
signal pending_sync_finished(synced_count: int, failed_count: int)
signal session_expired()

## Propias de BackendSession
signal login_succeeded(user: Dictionary)
signal login_failed(reason: String)
signal logout_completed()
signal session_restored(user: Dictionary)
signal session_restore_failed(reason: String)


# ── Dependencias internas ───────────────────────────────────────────────────

var _api: BackendApiClient
var _auth: AuthSession
var _sync: ProgressSyncService
var _current_user: Dictionary = {}
var _current_progress: Dictionary = {}


func _ready() -> void:
	# BackendApiClient y ProgressSyncService deben estar en el árbol porque
	# BackendApiClient crea HTTPRequest nodes y ProgressSyncService emite señales.
	_api = BackendApiClient.new()
	add_child(_api)

	_auth = AuthSession.new()  # RefCounted, no necesita árbol

	_sync = ProgressSyncService.new()
	add_child(_sync)
	_sync.setup(_api, _auth)

	# Reenviar señales de ProgressSyncService hacia el exterior
	_sync.sync_started.connect(func(): sync_started.emit())
	_sync.sync_succeeded.connect(func(p: Dictionary): sync_succeeded.emit(p))
	_sync.sync_failed.connect(func(r: String): sync_failed.emit(r))
	_sync.pending_sync_started.connect(func(c: int): pending_sync_started.emit(c))
	_sync.pending_sync_finished.connect(func(s: int, f: int): pending_sync_finished.emit(s, f))
	_sync.session_expired.connect(_on_session_expired)

	# Intentar restaurar sesión previa desde disco (deferred: árbol listo)
	call_deferred("_restore_session_async")


# ── Consultas de sesión ─────────────────────────────────────────────────────

func is_logged_in() -> bool:
	return _auth.is_logged_in()


func get_token() -> String:
	return _auth.get_token()


func get_username() -> String:
	return _auth.get_username()


func get_cached_user() -> Dictionary:
	return _current_user


func get_cached_progress() -> Dictionary:
	return _current_progress


func has_loaded_account_data() -> bool:
	return not _current_user.is_empty()


func clear_cached_account_data() -> void:
	_current_user.clear()
	_current_progress.clear()


func load_account_data() -> Dictionary:
	if not is_logged_in():
		return {
			"ok": false,
			"status": 401,
			"error": "No active session"
		}

	var me_result := await get_me()
	if not me_result.get("ok", false):
		return me_result

	var progress_result := await get_progress()
	if not progress_result.get("ok", false):
		return progress_result

	var me_data: Dictionary = me_result.get("data", {})
	var progress_data: Dictionary = progress_result.get("data", {})

	_current_user = me_data.get("user", me_data)
	_current_progress = progress_data

	return {
		"ok": true,
		"status": 200,
		"user": _current_user,
		"progress": _current_progress
	}


# ── Autenticación ───────────────────────────────────────────────────────────

func login(username_or_mail: String, password: String) -> Dictionary:
	var result := await _api.login(username_or_mail, password)
	_handle_auth_result(result)
	return result


## Registro de cuenta nueva.
## Si el backend devuelve accessToken, establece sesión y emite login_succeeded.
func register(
	username: String,
	name: String,
	mail: String,
	password: String,
	age: int = 0
) -> Dictionary:
	var result := await _api.register(username, name, mail, password, age)
	_handle_auth_result(result)
	return result


## GET /auth/me — perfil del usuario autenticado.
## Si no hay sesión activa, devuelve error 401 sin hacer HTTP.
func get_me() -> Dictionary:
	if not _auth.is_logged_in():
		return {"ok": false, "status": 401, "error": "No active session"}
	return await _api.get_me(_auth.get_token())


## GET /player/me/progress — progreso del jugador.
## Si no hay sesión activa, devuelve error 401 sin hacer HTTP.
func get_progress() -> Dictionary:
	if not _auth.is_logged_in():
		return {"ok": false, "status": 401, "error": "No active session"}
	return await _api.get_progress(_auth.get_token())


## POST /player/me/progress — sincroniza un RunSummary al finalizar una partida.
## Si no hay sesión activa, devuelve error sin lanzar excepción (modo offline).
## Emite sync_started / sync_succeeded / sync_failed / session_expired.
func save_progress(run_summary: Dictionary) -> Dictionary:
	if not _auth.is_logged_in():
		return {"ok": false, "status": 0, "error": "No active session"}
	return await _sync.sync(run_summary)


## Cierra la sesión en memoria y borra la sesión persistida en disco.
## No llama al backend (logout es stateless).
func logout() -> void:
	_auth.clear_session()
	BackendSessionStorage.clear_session()
	_current_user.clear()
	_current_progress.clear()
	logout_completed.emit()


# ── Handlers internos ───────────────────────────────────────────────────────

## Procesa la respuesta de login o register:
## si contiene accessToken, guarda sesión y emite login_succeeded;
## de lo contrario emite login_failed.
func _handle_auth_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		var reason: String = result.get(
			"error",
			"Error del servidor (status %d)" % result.get("status", 0)
		)
		login_failed.emit(reason)
		return

	var data: Dictionary = result.get("data", {})
	var access_token: String = data.get("accessToken", "")

	if access_token.is_empty():
		login_failed.emit("Respuesta OK pero sin accessToken")
		return

	var user: Dictionary = data.get("user", {})
	var username: String = user.get("username", "")
	_auth.set_session(access_token, username)
	BackendSessionStorage.save_session(access_token, username, user)
	login_succeeded.emit(user)
	_sync.retry_pending()


func _on_session_expired() -> void:
	_auth.clear_session()
	BackendSessionStorage.clear_session()
	_current_user.clear()
	_current_progress.clear()
	session_expired.emit()


## Intenta restaurar una sesión previa guardada en disco.
## Se ejecuta con call_deferred para no bloquear el arranque del juego.
## Si el token guardado es inválido, lo limpia silenciosamente.
func _restore_session_async() -> void:
	var stored := BackendSessionStorage.load_session()
	if stored.is_empty():
		return

	var token := str(stored.get("token", ""))
	var username := str(stored.get("username", ""))
	if token.is_empty():
		BackendSessionStorage.clear_session()
		return

	# Cargar en memoria antes de validar para que get_me() no falle por 401 local
	_auth.set_session(token, username)

	var result := await get_me()
	if result.get("ok", false):
		var data: Dictionary = result.get("data", {})
		var user: Dictionary = data.get("user", data)
		# Actualizar username si el servidor devuelve uno más fresco
		var fresh_username: String = user.get("username", username)
		_auth.set_session(token, fresh_username)
		print("[BackendSession] Sesión restaurada: ", fresh_username)
		session_restored.emit(user)
		_sync.retry_pending()
	else:
		print("[BackendSession] Token inválido o expirado — limpiando sesión local.")
		_auth.clear_session()
		BackendSessionStorage.clear_session()
		session_restore_failed.emit(str(result.get("error", "Sesión inválida")))
