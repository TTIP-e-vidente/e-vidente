# Autoload interno. Desde el juego usar AuthApi y SyncApi.
extends Node

const BACKGROUND_SYNC_INTERVAL_SECS := 300.0  # 5 minutos
const AvatarSyncServiceScript := preload("res://API/backend/sync/AvatarSyncService.gd")

signal sync_started()
signal sync_succeeded(progress: Dictionary)
signal sync_failed(reason: String)
signal pending_sync_started(count: int)
signal pending_sync_finished(synced_count: int, failed_count: int)
signal session_expired()
signal login_succeeded(user: Dictionary)
signal login_failed(reason: String)
signal logout_completed()
signal session_restored(user: Dictionary)
signal session_restore_failed(reason: String)
signal online_progress_synced(user: Dictionary)

var _api: BackendApiClient
var _auth: AuthSession
var _sync: ProgressSyncService
var _usuario_en_cache: Dictionary = {}
var _progreso_online_en_cache: Dictionary = {}
var _carga_online_en_curso: bool = false
var _ultimo_resultado_carga_online: Dictionary = {}
# Epoch de la sesión al que pertenecen la carga en curso y el último resultado.
# Evita que una carga de la cuenta anterior (en vuelo durante logout/login)
# pise el cache o el save local de la cuenta nueva.
var _epoch_carga_en_curso: int = -1
var _epoch_ultimo_resultado: int = -1
# Dirty-flag: si llega un trigger mientras el sync corre, lo re-ejecuta al terminar.
var _reintento_encolado: bool = false
# Login rechazado con EMAIL_NOT_VERIFIED: guarda el token acotado (scope
# email_verification), el usuario y la meta de envío del código. No es una
# sesión completa: solo habilita los endpoints de verificación de mail.
var _verificacion_login_pendiente: Dictionary = {}
# Evita sondas concurrentes del modo auto.
var _sonda_modo_en_curso: bool = false


## En api_mode=auto: sondea el Express local (timeout corto). Si responde,
## el juego usa el backend local; si no, Supabase Edge. También determina el
## espacio de datos (local vs supabase) para no mezclar saves entre entornos.
## Se re-ejecuta tras BackendConfig.recargar() (p. ej. botón Reintentar).
func _asegurar_modo_backend_resuelto() -> void:
	if not BackendConfig.es_modo_auto() or BackendConfig.auto_esta_resuelto():
		return
	if _sonda_modo_en_curso:
		while _sonda_modo_en_curso:
			await get_tree().process_frame
		return
	_sonda_modo_en_curso = true

	var local_url := BackendConfig.obtener_local_base_url()
	var salud := await _sondear_url_local(local_url + "/health")
	var db_remota := false
	if salud:
		var db := await _sondear_json_local(local_url + "/health/db")
		db_remota = bool(db.get("remote", false))
	BackendConfig.aplicar_resolucion_auto(salud, db_remota)
	# El cliente HTTP cachea base_url en _init: refrescarla tras resolver.
	_api.base_url = BackendConfig.obtener_base_url()
	_sonda_modo_en_curso = false


func _sondear_url_local(url: String) -> bool:
	var resultado := await _sondear_json_local(url)
	return not resultado.is_empty()


## GET con timeout corto contra el Express local. Devuelve el JSON del body
## o {} si no respondió / no es JSON válido.
func _sondear_json_local(url: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 1.5
	add_child(http)
	var start_error := http.request(url)
	if start_error != OK:
		http.queue_free()
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		return {}
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


## Clave que separa los datos locales (save vinculado, cola de sync, avatar
## pendiente) por entorno: "agus" en Supabase, "agus@local" en Postgres local.
func _componer_clave_cuenta(username: String) -> String:
	var clean := username.strip_edges()
	if clean.is_empty():
		return ""
	return clean + BackendConfig.obtener_sufijo_cuenta()


func obtener_clave_cuenta() -> String:
	return _auth.obtener_clave_cuenta()


func _ready() -> void:
	_api = BackendApiClient.new()
	add_child(_api)

	_auth = AuthSession.new()

	_sync = ProgressSyncService.new()
	add_child(_sync)
	_sync.configurar(_api, _auth)

	_sync.sync_started.connect(func(): sync_started.emit())
	_sync.sync_succeeded.connect(func(p: Dictionary): sync_succeeded.emit(p))
	_sync.sync_failed.connect(func(r: String): sync_failed.emit(r))
	_sync.pending_sync_started.connect(func(c: int): pending_sync_started.emit(c))
	_sync.pending_sync_finished.connect(_al_sync_pendientes_terminado)
	_sync.session_expired.connect(_al_expirar_sesion)

	var bg_timer := Timer.new()
	bg_timer.wait_time = BACKGROUND_SYNC_INTERVAL_SECS
	bg_timer.autostart = true
	bg_timer.timeout.connect(_on_background_sync_timer)
	add_child(bg_timer)

	call_deferred("_restaurar_sesion_guardada")
	# Limpiar ítems FAILED/SYNCED antiguos al inicio para evitar acumulación indefinida.
	call_deferred("_limpiar_cola_inicial")


func esta_logueado() -> bool:
	return _auth.esta_logueado()


func obtener_token() -> String:
	return _auth.obtener_token()


func obtener_usuario() -> String:
	return _auth.obtener_usuario()


func obtener_usuario_en_cache() -> Dictionary:
	return _usuario_en_cache


func _mail_verified_at_valido(verified_at: Variant) -> bool:
	if verified_at == null:
		return false
	var texto := str(verified_at).strip_edges()
	if texto.is_empty() or texto.to_lower() == "null":
		return false
	return true


func _persistir_usuario_en_cache(user: Dictionary) -> void:
	if user.is_empty():
		return
	var normalizado := user.duplicate(true)
	if not _mail_verified_at_valido(normalizado.get("mail_verified_at", null)):
		normalizado.erase("mail_verified_at")
	_usuario_en_cache = normalizado
	BackendSessionStorage.guardar_sesion(
		_auth.obtener_token(),
		_auth.obtener_usuario(),
		_usuario_en_cache,
		BackendConfig.obtener_entorno_datos()
	)


func _aplicar_mail_verified_at_en_cache(verified_at: Variant) -> void:
	if _usuario_en_cache.is_empty():
		return
	if _mail_verified_at_valido(verified_at):
		_usuario_en_cache["mail_verified_at"] = verified_at
	else:
		_usuario_en_cache.erase("mail_verified_at")
	_persistir_usuario_en_cache(_usuario_en_cache)


func limpiar_mail_verificado_en_cache() -> void:
	_aplicar_mail_verified_at_en_cache(null)


func refrescar_usuario_en_cache() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await obtener_usuario_del_servidor()
	if not bool(resultado.get("ok", false)):
		return resultado
	if _auth.obtener_epoch() != epoch:
		return _resultado_sesion_cambiada()
	var data: Variant = resultado.get("data", {})
	if data is Dictionary:
		var user_data: Variant = (data as Dictionary).get("user", data)
		if user_data is Dictionary and not (user_data as Dictionary).is_empty():
			_persistir_usuario_en_cache(user_data as Dictionary)
	return resultado


func obtener_progreso_online_en_cache() -> Dictionary:
	return _progreso_online_en_cache


func tiene_datos_online_en_memoria() -> bool:
	return not _usuario_en_cache.is_empty()


func limpiar_cache_online() -> void:
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()


func limpiar_cache_progreso_online() -> void:
	if _progreso_online_en_cache.is_empty():
		return
	_progreso_online_en_cache["completedNodes"] = []
	var progress_rows: Variant = _progreso_online_en_cache.get("progress", [])
	if progress_rows is Array:
		for row in progress_rows as Array:
			if row is Dictionary and str((row as Dictionary).get("restriction_type", "")) == "CELIAQUIA":
				(row as Dictionary)["total_exp"] = 0
				(row as Dictionary)["completed_nodes_count"] = 0
				(row as Dictionary)["completed_games_count"] = 0
				(row as Dictionary)["map_completed"] = false


func cargar_datos_online() -> Dictionary:
	var epoch := _auth.obtener_epoch()

	if _carga_online_en_curso and _epoch_carga_en_curso == epoch:
		# Carga de la misma sesión ya en curso: esperar y compartir su resultado.
		while _carga_online_en_curso:
			await get_tree().process_frame
		if _auth.obtener_epoch() == epoch and _epoch_ultimo_resultado == epoch:
			return _ultimo_resultado_carga_online.duplicate(true)
		return _resultado_sesion_cambiada()

	# Si quedó una carga de una sesión anterior, esperar a que termine sin reusarla.
	while _carga_online_en_curso:
		await get_tree().process_frame
	if _auth.obtener_epoch() != epoch:
		return _resultado_sesion_cambiada()

	_carga_online_en_curso = true
	_epoch_carga_en_curso = epoch
	var resultado := await _cargar_datos_online_interno(epoch)
	_ultimo_resultado_carga_online = resultado
	_epoch_ultimo_resultado = epoch
	_carga_online_en_curso = false
	return resultado.duplicate(true)


func _resultado_sesion_cambiada() -> Dictionary:
	return {"ok": false, "status": 0, "error": "La sesión cambió durante la operación"}


func _cargar_datos_online_interno(epoch: int) -> Dictionary:
	if not esta_logueado():
		return {
			"ok": false,
			"status": 401,
			"error": "No active session"
		}

	var resultado_usuario: Dictionary = await obtener_usuario_del_servidor()
	if not resultado_usuario.get("ok", false):
		return resultado_usuario
	if _auth.obtener_epoch() != epoch:
		return _resultado_sesion_cambiada()

	var datos_usuario: Dictionary = resultado_usuario.get("data", {})
	_usuario_en_cache = datos_usuario.get("user", datos_usuario)
	# Clave de cuenta (username + entorno): separa el save local por entorno.
	var username_sync := str(_auth.obtener_clave_cuenta()).strip_edges()

	var resultado_progreso: Dictionary = await obtener_progreso_del_servidor()
	if not resultado_progreso.get("ok", false):
		return resultado_progreso
	if _auth.obtener_epoch() != epoch:
		return _resultado_sesion_cambiada()

	var datos_progreso: Dictionary = resultado_progreso.get("data", {})
	var forzar_reset_remoto := (
		SaveManager != null
		and SaveManager.has_method("debe_forzar_reset_remoto_antes_de_sync")
		and SaveManager.debe_forzar_reset_remoto_antes_de_sync(username_sync)
	)

	if forzar_reset_remoto:
		var reset_result: Dictionary = await reiniciar_progreso_online("CELIAQUIA")
		if _auth.obtener_epoch() != epoch:
			return _resultado_sesion_cambiada()
		if bool(reset_result.get("ok", false)):
			var reset_data: Variant = reset_result.get("data", {})
			if reset_data is Dictionary and not (reset_data as Dictionary).is_empty():
				datos_progreso = reset_data as Dictionary
			if (
				SaveManager != null
				and SaveManager.has_method("confirmar_reset_remoto_completado")
			):
				SaveManager.call(
					"confirmar_reset_remoto_completado",
					datos_progreso,
					username_sync,
					true
				)
		elif SaveManager.has_method("marcar_reset_remoto_pendiente"):
			SaveManager.call("marcar_reset_remoto_pendiente")
			if forzar_reset_remoto:
				datos_progreso = {}

	_usuario_en_cache = datos_usuario.get("user", datos_usuario)
	_progreso_online_en_cache = datos_progreso
	_aplicar_progreso_online_al_save_local()
	# Fire-and-forget: sube el avatar pendiente (si quedó uno de una falla de
	# red) o descarga el del backend si no hay uno local, con reintentos.
	_sincronizar_avatar_post_login(epoch)
	if LocalSyncQueue.contar_pendientes() > 0 and not _sync.esta_sincronizando():
		_sync.reintentar_pendientes()

	var resultado_sync := {
		"ok": true,
		"status": 200,
		"user": _usuario_en_cache,
		"progress": _progreso_online_en_cache
	}
	online_progress_synced.emit(_usuario_en_cache.duplicate(true))
	return resultado_sync


func verificar_estado_del_servidor() -> Dictionary:
	await _asegurar_modo_backend_resuelto()
	var salud_api := await _api.verificar_salud_api()
	if not salud_api.get("ok", false):
		return {"ok": false, "phase": "api", "result": salud_api}
	var salud_db := await _api.verificar_salud_db()
	if not salud_db.get("ok", false):
		return {"ok": false, "phase": "db", "result": salud_db}
	var raw_db: Variant = salud_db.get("data", {})
	if raw_db is Dictionary and not bool((raw_db as Dictionary).get("remote", false)):
		return {
			"ok": false,
			"phase": "db",
			"result": {
				"ok": false,
				"status": 503,
				"code": "NOT_SUPABASE",
				"error": "El backend no está conectado a Supabase.",
			},
		}
	return {"ok": true}


func verificar_stack_completo() -> Dictionary:
	await _asegurar_modo_backend_resuelto()
	var salud_api := await _api.verificar_salud_api()
	if not salud_api.get("ok", false):
		return {"ok": false, "phase": "api", "result": salud_api}

	var salud_db := await _api.verificar_salud_db()
	if not salud_db.get("ok", false):
		return {"ok": false, "phase": "db", "result": salud_db}

	var db_data: Dictionary = {}
	var raw_db: Variant = salud_db.get("data", {})
	if raw_db is Dictionary:
		db_data = raw_db as Dictionary

	if not bool(db_data.get("remote", false)):
		return {
			"ok": false,
			"phase": "db",
			"result": {
				"ok": false,
				"status": 503,
				"code": "NOT_SUPABASE",
				"error": "El backend no está conectado a Supabase.",
			},
		}

	if not BackendConfig.es_supabase() and not BackendConfig.es_modo_supabase_edge():
		push_warning(
			"[BackendSession] backend.local.json no marca db=supabase — corré npm run sync:godot-config:staging"
		)

	var migrations: Dictionary = {}
	var raw_migrations: Variant = db_data.get("migrations", {})
	if raw_migrations is Dictionary:
		migrations = raw_migrations as Dictionary

	var salud_email := await _api.verificar_salud_email()
	var email_data: Dictionary = {}
	var raw_email: Variant = salud_email.get("data", {})
	if raw_email is Dictionary:
		email_data = raw_email as Dictionary

	return {
		"ok": true,
		"base_url": BackendConfig.obtener_api_base_url(),
		"db": {
			"remote": bool(db_data.get("remote", false)),
			"migrations_healthy": bool(migrations.get("healthy", true)),
		},
		"email": {
			"enabled": bool(email_data.get("email_enabled", false)),
			"configured": bool(email_data.get("delivery_configured", false)),
			"dev_code_in_logs": bool(email_data.get("dev_code_in_logs", false)),
		},
	}


func verificar_salud_email() -> Dictionary:
	return await _api.verificar_salud_email()


func iniciar_sesion(usuario_o_mail: String, clave: String) -> Dictionary:
	var listo := await _asegurar_servidor_listo()
	if not listo.get("ok", false):
		return listo
	_verificacion_login_pendiente.clear()
	var resultado := await _api.iniciar_sesion(usuario_o_mail, clave)
	if (
		not bool(resultado.get("ok", false))
		and str(resultado.get("code", "")) == "EMAIL_NOT_VERIFIED"
	):
		_guardar_verificacion_login_pendiente(resultado)
		return resultado
	_procesar_resultado_de_auth(resultado)
	return resultado


func _guardar_verificacion_login_pendiente(resultado: Dictionary) -> void:
	var data: Variant = resultado.get("data", {})
	if not data is Dictionary:
		return
	var token := str((data as Dictionary).get("verification_token", "")).strip_edges()
	if token.is_empty():
		return
	var user: Variant = (data as Dictionary).get("user", {})
	var verification: Variant = (data as Dictionary).get("verification", {})
	var user_dict: Dictionary = {}
	if user is Dictionary:
		user_dict = user as Dictionary
	var verification_dict: Dictionary = {}
	if verification is Dictionary:
		verification_dict = verification as Dictionary
	_verificacion_login_pendiente = {
		"token": token,
		"user": user_dict,
		"verification": verification_dict,
	}


func hay_verificacion_de_login_pendiente() -> bool:
	return not _verificacion_login_pendiente.is_empty()


func obtener_usuario_verificacion_pendiente() -> Dictionary:
	var user: Variant = _verificacion_login_pendiente.get("user", {})
	if user is Dictionary:
		return (user as Dictionary).duplicate(true)
	return {}


func obtener_meta_verificacion_pendiente() -> Dictionary:
	var meta: Variant = _verificacion_login_pendiente.get("verification", {})
	if meta is Dictionary:
		return (meta as Dictionary).duplicate(true)
	return {}


func limpiar_verificacion_de_login_pendiente() -> void:
	_verificacion_login_pendiente.clear()


## Token válido para los endpoints de verificación de mail: la sesión completa
## si existe, o el token acotado del login rechazado por EMAIL_NOT_VERIFIED.
func _token_para_verificacion() -> String:
	if _auth.esta_logueado():
		return _auth.obtener_token()
	return str(_verificacion_login_pendiente.get("token", ""))


func registrar_cuenta(
	usuario: String,
	nombre: String,
	mail: String,
	clave: String,
	fecha_nacimiento: Variant = null,
	acepta_notificaciones_mail: bool = true,
	solicitar_verificacion_mail: bool = false
) -> Dictionary:
	var listo := await _asegurar_servidor_listo()
	if not listo.get("ok", false):
		return listo
	var resultado := await _api.registrar_cuenta(
		usuario,
		nombre,
		mail,
		clave,
		fecha_nacimiento,
		acepta_notificaciones_mail,
		solicitar_verificacion_mail
	)
	_procesar_resultado_de_auth(resultado)
	return resultado


func subir_avatar(base64_data: String, mime_type: String) -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var clave_cuenta := _auth.obtener_clave_cuenta()
	var resultado := await _api.subir_avatar(_auth.obtener_token(), base64_data, mime_type)
	_verificar_sesion_expirada(resultado, epoch)
	if bool(resultado.get("ok", false)):
		AvatarSyncServiceScript.limpiar_subida_pendiente(clave_cuenta)
	elif int(resultado.get("status", 0)) == 0 or int(resultado.get("status", 0)) >= 500:
		# Falla de red o del servidor: el avatar local queda como pendiente de
		# subir y se reintenta en el próximo login/carga online.
		AvatarSyncServiceScript.marcar_subida_pendiente(clave_cuenta, mime_type)
	return resultado


func eliminar_avatar_online() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.eliminar_avatar(_auth.obtener_token())
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


func descargar_avatar_publico(user_id: String) -> Dictionary:
	return await _api.descargar_avatar_publico(user_id)


func actualizar_perfil_online(
	nombre: String,
	mail: String,
	fecha_nacimiento: String,
	notificaciones_mail: Variant = null,
	forzar_sincronizar_mail: bool = false
) -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "error": "No active session"}

	var payload := {}
	var cached := _usuario_en_cache

	var clean_name := nombre.strip_edges()
	if clean_name.is_empty():
		clean_name = obtener_usuario()
	var cached_name := str(cached.get("name", cached.get("username", ""))).strip_edges()
	if cached.is_empty() or clean_name != cached_name:
		payload["name"] = clean_name

	var clean_mail := mail.strip_edges()
	var cached_mail := str(cached.get("mail", "")).strip_edges()
	if forzar_sincronizar_mail and not clean_mail.is_empty():
		payload["mail"] = clean_mail
	elif _mail_normalizado(clean_mail) != _mail_normalizado(cached_mail):
		payload["mail"] = clean_mail if not clean_mail.is_empty() else null

	var clean_birth := fecha_nacimiento.strip_edges()
	var cached_birth := str(cached.get("birth_date", "")).strip_edges()
	if clean_birth != cached_birth:
		payload["birth_date"] = clean_birth if not clean_birth.is_empty() else null

	if notificaciones_mail is bool:
		var cached_notifications := bool(cached.get("email_notifications_enabled", false))
		if cached.is_empty() or cached_notifications != notificaciones_mail:
			payload["email_notifications_enabled"] = notificaciones_mail

	if payload.is_empty():
		return {"ok": true, "data": {"user": cached.duplicate(true)}, "skipped": true}

	var epoch := _auth.obtener_epoch()
	var resultado := await _api.actualizar_perfil(_auth.obtener_token(), payload)
	_verificar_sesion_expirada(resultado, epoch)
	if not bool(resultado.get("ok", false)):
		return resultado
	if _auth.obtener_epoch() != epoch:
		# La sesión cambió mientras se actualizaba: no pisar el cache de la nueva.
		return resultado

	var data: Variant = resultado.get("data", {})
	if data is Dictionary:
		var user_data: Variant = (data as Dictionary).get("user", {})
		if user_data is Dictionary and not (user_data as Dictionary).is_empty():
			_persistir_usuario_en_cache(user_data as Dictionary)

	if payload.has("mail") and not clean_mail.is_empty():
		var persisted := str(_usuario_en_cache.get("mail", "")).strip_edges()
		if _mail_normalizado(persisted) != _mail_normalizado(clean_mail):
			return {
				"ok": false,
				"status": 409,
				"code": "MAIL_SYNC_MISMATCH",
				"error": "El mail del servidor no coincide con el del formulario.",
				"data": data if data is Dictionary else {},
			}

	resultado["skipped"] = false
	return resultado


func _mail_normalizado(value: String) -> String:
	return value.strip_edges().to_lower()


## Solicita el envío de un código de verificación de 6 dígitos al email configurado.
## Retorna status 'sent', 'already_verified' o error (rate_limited, 422, etc.).
## Acepta también el token acotado del login rechazado por EMAIL_NOT_VERIFIED.
func solicitar_verificacion_email(mail_esperado: String = "") -> Dictionary:
	var token := _token_para_verificacion()
	if token.is_empty():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.solicitar_verificacion_email(token, mail_esperado)
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


## Confirma el código de verificación ingresado por el usuario (6 dígitos numéricos).
## Retorna status 'verified' o error (invalid, expired, no_pending).
## Si el flujo venía de un login bloqueado (token acotado), la respuesta trae
## un accessToken completo y acá se establece la sesión plena.
func confirmar_verificacion_email(codigo: String) -> Dictionary:
	var token := _token_para_verificacion()
	if token.is_empty():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.confirmar_verificacion_email(token, codigo.strip_edges())
	_verificar_sesion_expirada(resultado, epoch)
	# Si se verificó, actualizar el cache de usuario con mail_verified_at
	if bool(resultado.get("ok", false)):
		var data: Variant = resultado.get("data", {})
		if data is Dictionary:
			var data_dict := data as Dictionary
			if not _auth.esta_logueado():
				_establecer_sesion_post_verificacion(data_dict)
			_aplicar_mail_verified_at_en_cache(data_dict.get("mail_verified_at", null))
			if SaveManager != null and SaveManager.has_method("preparar_cuenta_online"):
				SaveManager.call("preparar_cuenta_online", _usuario_en_cache)
	return resultado


## Cambia el token acotado del login bloqueado por la sesión completa que
## devuelve verify-email-confirm al verificar.
func _establecer_sesion_post_verificacion(data: Dictionary) -> void:
	var access_token := str(data.get("accessToken", "")).strip_edges()
	if access_token.is_empty() or not hay_verificacion_de_login_pendiente():
		return
	var user := obtener_usuario_verificacion_pendiente()
	var username := str(user.get("username", ""))
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()
	_descartar_resultado_carga_online()
	_auth.establecer_sesion(access_token, username, _componer_clave_cuenta(username))
	if not user.is_empty():
		_persistir_usuario_en_cache(user)
	limpiar_verificacion_de_login_pendiente()
	if SaveManager != null and SaveManager.has_method("preparar_cuenta_online"):
		SaveManager.call("preparar_cuenta_online", _usuario_en_cache, obtener_clave_cuenta())
	login_succeeded.emit(_usuario_en_cache.duplicate(true))
	print("[BackendSession] Sesión completa establecida tras verificar el mail: ", username)
	# En el login normal esto lo dispara iniciar_sesion_completa; acá la sesión
	# nace en el confirm, así que se carga el progreso online en segundo plano.
	call_deferred("cargar_datos_online")


func obtener_estado_verificacion_email() -> Dictionary:
	var token := _token_para_verificacion()
	if token.is_empty():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.obtener_estado_email(token)
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


func obtener_usuario_del_servidor() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.obtener_mi_usuario(_auth.obtener_token())
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


func obtener_progreso_del_servidor() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.obtener_progreso(_auth.obtener_token())
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


func reiniciar_progreso_online(restriction: String = "CELIAQUIA") -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.reiniciar_progreso(_auth.obtener_token(), restriction)
	_verificar_sesion_expirada(resultado, epoch)
	if _auth.obtener_epoch() != epoch:
		return resultado
	if bool(resultado.get("ok", false)):
		var data: Variant = resultado.get("data", {})
		if data is Dictionary:
			_progreso_online_en_cache = (data as Dictionary).duplicate(true)
	return resultado


# --- Leaderboard ---

func obtener_leaderboard_online(
	scope: String = "global_xp",
	limit: int = 50,
	offset: int = 0,
	include_self: bool = false
) -> Dictionary:
	var token := _auth.obtener_token() if _auth.esta_logueado() else ""
	return await _api.obtener_leaderboard(token, scope, limit, offset, include_self)


func obtener_mi_posicion_leaderboard_online() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	return await _api.obtener_mi_posicion_leaderboard(_auth.obtener_token())


# Obtiene el contexto competitivo del jugador autenticado.
# Retorna { available: true, current, next, exp_to_next_rank, ... } o { available: false }.
func obtener_resumen_ranking_online(scope: String = "global_xp") -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	return await _api.obtener_resumen_ranking(_auth.obtener_token(), scope)


func obtener_meta_leaderboard_online() -> Dictionary:
	return await _api.obtener_meta_leaderboard()


## Marca la sesión como expirada solo si el 401 corresponde a la sesión actual:
## un 401 de una request vieja (emitida antes de un logout/login) no debe
## limpiar la sesión nueva.
func _verificar_sesion_expirada(resultado: Dictionary, epoch: int) -> void:
	if _auth.obtener_epoch() != epoch:
		return
	if resultado.get("status", 0) == 401 and _auth.esta_logueado():
		_al_expirar_sesion()


func guardar_progreso_online(resumen_partida: Dictionary) -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 0, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _sync.sincronizar(resumen_partida)
	if _auth.obtener_epoch() != epoch:
		# La sesión cambió durante el POST: no aplicar el resultado al save actual.
		return resultado
	if bool(resultado.get("ok", false)):
		_aplicar_racha_de_respuesta_sync(resultado.get("data", {}))
	return resultado


func _aplicar_racha_de_respuesta_sync(data: Variant) -> void:
	if not data is Dictionary:
		return
	var payload: Dictionary = data as Dictionary
	var summary: Variant = payload.get("summary", {})

	# Aplicar completedNodes del resumen de sync al save local (auto-guardado post-partida).
	if summary is Dictionary and SaveManager != null:
		var cn_raw: Variant = (summary as Dictionary).get("completedNodes", [])
		if cn_raw is Array and not (cn_raw as Array).is_empty():
			if SaveManager.has_method("fusionar_completados_desde_sync"):
				SaveManager.call("fusionar_completados_desde_sync", cn_raw as Array)
		# Mantener cache online actualizado con los nodos del servidor.
		var cn_for_cache: Variant = (summary as Dictionary).get("completedNodes", [])
		if cn_for_cache is Array and not _progreso_online_en_cache.is_empty():
			_progreso_online_en_cache["completedNodes"] = cn_for_cache

	var streak: Dictionary = {}
	if summary is Dictionary and not (summary as Dictionary).get("streak", {}).is_empty():
		streak = (summary as Dictionary).get("streak", {})
	elif payload.has("streak"):
		streak = payload.get("streak", {})
	if streak.is_empty() or SaveManager == null:
		return
	SaveManager.aplicar_racha_sincronizada(streak)
	if not _progreso_online_en_cache.is_empty():
		_progreso_online_en_cache["streak"] = streak


func reintentar_sync_pendiente() -> void:
	if not _auth.esta_logueado():
		return
	if _sync.esta_sincronizando():
		_reintento_encolado = true
		return
	_sync.reintentar_pendientes()


func reintentar_todos_sync_pendiente() -> void:
	if not _auth.esta_logueado():
		return
	_sync.reintentar_pendientes(100)


func esta_sincronizando_sync() -> bool:
	return _sync.esta_sincronizando()


func esperar_drenaje_sync_pendiente(max_items: int = 100, max_rounds: int = 5) -> void:
	if not _auth.esta_logueado():
		return
	var rounds := 0
	while _auth.esta_logueado() and rounds < max_rounds:
		var pending := LocalSyncQueue.contar_pendientes()
		if pending <= 0 and not _sync.esta_sincronizando():
			return
		if _sync.esta_sincronizando():
			await _esperar_sync_con_timeout(10.0)
		else:
			_sync.reintentar_pendientes(max_items)
			await _esperar_sync_con_timeout(10.0)
		rounds += 1
		if LocalSyncQueue.contar_pendientes() <= 0:
			return


func _al_sync_pendientes_terminado(synced: int, failed: int) -> void:
	pending_sync_finished.emit(synced, failed)
	if _reintento_encolado:
		_reintento_encolado = false
		if _auth.esta_logueado() and LocalSyncQueue.contar_pendientes() > 0:
			_sync.reintentar_pendientes()


## Espera [signal pending_sync_finished] con timeout de seguridad.
## Evita que [method esperar_drenaje_sync_pendiente] quede bloqueado indefinidamente
## si la señal nunca se emite por un bug en [ProgressSyncService].
func _esperar_sync_con_timeout(timeout_s: float) -> void:
	var timer := get_tree().create_timer(timeout_s)
	var timeout_state := {"expired": false}
	timer.timeout.connect(func() -> void: timeout_state["expired"] = true, CONNECT_ONE_SHOT)
	while not timeout_state["expired"] and _sync.esta_sincronizando():
		await get_tree().process_frame
	if timeout_state["expired"]:
		push_warning("[BackendSession] esperar_drenaje_sync_pendiente: timeout tras %.0fs" % timeout_s)


func _limpiar_cola_inicial() -> void:
	LocalSyncQueue.limpiar_cola()


func _on_background_sync_timer() -> void:
	if not _auth.esta_logueado():
		return
	if _sync.esta_sincronizando():
		return
	if LocalSyncQueue.contar_pendientes() <= 0:
		return
	_sync.reintentar_pendientes()


func cerrar_sesion() -> void:
	_auth.limpiar_sesion()
	BackendSessionStorage.borrar_sesion()
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()
	_verificacion_login_pendiente.clear()
	_descartar_resultado_carga_online()
	logout_completed.emit()


func _descartar_resultado_carga_online() -> void:
	_ultimo_resultado_carga_online = {}
	_epoch_ultimo_resultado = -1


func _asegurar_servidor_listo() -> Dictionary:
	await _asegurar_modo_backend_resuelto()
	var salud_api := await _api.verificar_salud_api()
	if not salud_api.get("ok", false):
		var resultado: Dictionary = salud_api.duplicate()
		resultado["phase"] = "api"
		return resultado
	var salud_db := await _api.verificar_salud_db()
	if not salud_db.get("ok", false):
		var resultado: Dictionary = salud_db.duplicate()
		resultado["phase"] = "db"
		return resultado
	return {"ok": true}


func _procesar_resultado_de_auth(resultado: Dictionary) -> void:
	if not resultado.get("ok", false):
		var motivo: String = resultado.get(
			"error",
			"Error del servidor (status %d)" % resultado.get("status", 0)
		)
		login_failed.emit(motivo)
		return

	var data: Dictionary = resultado.get("data", {})
	var access_token: String = data.get("accessToken", "")

	if access_token.is_empty():
		login_failed.emit("Respuesta OK pero sin accessToken")
		return

	var user: Dictionary = data.get("user", {})
	var username: String = user.get("username", "")
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()
	_descartar_resultado_carga_online()
	_auth.establecer_sesion(access_token, username, _componer_clave_cuenta(username))
	if not user.is_empty():
		_persistir_usuario_en_cache(user.duplicate(true))
	if SaveManager != null and SaveManager.has_method("preparar_cuenta_online"):
		SaveManager.call("preparar_cuenta_online", _usuario_en_cache, obtener_clave_cuenta())
	login_succeeded.emit(_usuario_en_cache.duplicate(true))


func _al_expirar_sesion() -> void:
	if not _auth.esta_logueado():
		return
	print("[BackendSession] Sesión expirada — limpiando datos de sesión")
	if SaveManager != null and SaveManager.has_method("al_cerrar_sesion_online"):
		SaveManager.call("al_cerrar_sesion_online")
	_auth.limpiar_sesion()
	BackendSessionStorage.borrar_sesion()
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()
	_verificacion_login_pendiente.clear()
	_descartar_resultado_carga_online()
	session_expired.emit()


func _restaurar_sesion_guardada() -> void:
	var guardado := BackendSessionStorage.cargar_sesion()
	if guardado.is_empty():
		return

	var token := str(guardado.get("token", ""))
	var username := str(guardado.get("username", ""))
	if token.is_empty():
		BackendSessionStorage.borrar_sesion()
		return

	# Resolver el modo (auto: ¿Express local o Supabase?) ANTES de restaurar:
	# un token de un entorno no debe usarse contra el otro ni mezclar saves.
	await _asegurar_modo_backend_resuelto()
	var entorno_guardado := str(guardado.get("entorno", BackendConfig.ENTORNO_SUPABASE))
	if entorno_guardado != BackendConfig.obtener_entorno_datos():
		print(
			"[BackendSession] Sesión guardada de otro entorno (%s ≠ %s) — no se restaura."
			% [entorno_guardado, BackendConfig.obtener_entorno_datos()]
		)
		return

	_auth.establecer_sesion(token, username, _componer_clave_cuenta(username))
	var epoch := _auth.obtener_epoch()

	var resultado := await obtener_usuario_del_servidor()
	if _auth.obtener_epoch() != epoch:
		# Hubo logout o login durante la verificación: no resucitar la sesión vieja.
		print("[BackendSession] Restauración cancelada: la sesión cambió durante la verificación.")
		return
	if resultado.get("ok", false):
		var data: Dictionary = resultado.get("data", {})
		var user: Dictionary = data.get("user", data)
		var username_fresco: String = user.get("username", username)
		_auth.establecer_sesion(token, username_fresco, _componer_clave_cuenta(username_fresco))
		if SaveManager != null and SaveManager.has_method("preparar_cuenta_online"):
			SaveManager.call("preparar_cuenta_online", user, obtener_clave_cuenta())
		print("[BackendSession] Sesión restaurada: ", username_fresco)
		session_restored.emit(user)
		await cargar_datos_online()
		_sync.reintentar_pendientes()
	else:
		print("[BackendSession] Token inválido o expirado — limpiando sesión local.")
		_auth.limpiar_sesion()
		BackendSessionStorage.borrar_sesion()
		_usuario_en_cache.clear()
		_progreso_online_en_cache.clear()
		_descartar_resultado_carga_online()
		if SaveManager != null and SaveManager.has_method("activar_modo_invitado_para_juego"):
			SaveManager.call("activar_modo_invitado_para_juego")
		session_restore_failed.emit(str(resultado.get("error", "Sesión inválida")))


func _aplicar_progreso_online_al_save_local() -> void:
	if _usuario_en_cache.is_empty():
		return
	if SaveManager == null:
		return
	var completed_count := 0
	var completed_nodes: Variant = _progreso_online_en_cache.get("completedNodes", [])
	if completed_nodes is Array:
		completed_count = (completed_nodes as Array).size()
	print(
		"[BackendSession] Aplicando cuenta online user=",
		_usuario_en_cache.get("username", ""),
		" completedNodes=",
		completed_count,
		" streak=",
		_progreso_online_en_cache.get("streak", {})
	)
	SaveManager.sincronizar_con_cuenta_online(
		_usuario_en_cache,
		_progreso_online_en_cache,
		obtener_clave_cuenta()
	)


func _sincronizar_avatar_post_login(epoch: int) -> void:
	if SaveManager == null or not _auth.esta_logueado():
		return
	var usuario := _auth.obtener_clave_cuenta()
	if AvatarSyncServiceScript.hay_subida_pendiente(usuario):
		# El avatar local es más nuevo que el remoto (upload fallido previo):
		# reintentar la subida en vez de pisar lo local con la descarga.
		await _reintentar_subida_avatar_pendiente(epoch)
		return
	await _descargar_avatar_si_falta(epoch)


func _reintentar_subida_avatar_pendiente(epoch: int) -> void:
	var local_path := SaveManager.obtener_ruta_avatar_usuario_actual()
	if local_path.is_empty():
		AvatarSyncServiceScript.limpiar_subida_pendiente(_auth.obtener_clave_cuenta())
		return
	var bytes := FileAccess.get_file_as_bytes(local_path)
	if bytes.is_empty():
		AvatarSyncServiceScript.limpiar_subida_pendiente(_auth.obtener_clave_cuenta())
		return
	if _auth.obtener_epoch() != epoch:
		return
	var mime := AvatarSyncServiceScript.mime_desde_ruta(local_path)
	var resultado := await subir_avatar(Marshalls.raw_to_base64(bytes), mime)
	if bool(resultado.get("ok", false)):
		print("[BackendSession] Avatar pendiente subido tras reintento.")


func _descargar_avatar_si_falta(epoch: int) -> void:
	if SaveManager == null or not _auth.esta_logueado():
		return

	var local_path := SaveManager.obtener_ruta_avatar_usuario_actual()
	if not local_path.is_empty() and not SaveManager.es_ruta_avatar_vinculada(local_path):
		SaveManager.limpiar_avatar_perfil()
		local_path = ""

	# Reintentos con espera creciente: una falla transitoria de red al loguear
	# no debe dejar al jugador sin avatar hasta el próximo login.
	var intentos := 1 + AvatarSyncServiceScript.DELAYS_DESCARGA.size()
	for intento in range(intentos):
		if intento > 0:
			var delay: float = AvatarSyncServiceScript.DELAYS_DESCARGA[intento - 1]
			await get_tree().create_timer(delay).timeout
			if _auth.obtener_epoch() != epoch or not _auth.esta_logueado():
				return
		var resultado := await _api.descargar_avatar(_auth.obtener_token())
		if _auth.obtener_epoch() != epoch:
			# Cambió la cuenta mientras se descargaba: no guardar el avatar
			# de la cuenta anterior bajo la clave de la nueva.
			return
		if bool(resultado.get("ok", false)):
			var data: Variant = resultado.get("data", {})
			if not data is Dictionary:
				return
			var raw_b64: Variant = (data as Dictionary).get("data", null)
			if raw_b64 == null:
				return
			var b64 := str(raw_b64)
			var raw_mime: Variant = (data as Dictionary).get("mimeType", null)
			var mime := str(raw_mime) if raw_mime != null else "image/png"
			if b64.is_empty():
				return
			_guardar_avatar_descargado(b64, mime)
			return
		if int(resultado.get("status", 0)) != 0 and int(resultado.get("status", 0)) < 500:
			# Error definitivo (4xx): reintentar no va a cambiar el resultado.
			return
	push_warning("[BackendSession] No se pudo descargar el avatar tras varios intentos.")


func _guardar_avatar_descargado(base64_data: String, mime_type: String) -> void:
	if SaveManager == null:
		return
	var clean_b64 := base64_data.strip_edges()
	var comma_pos := clean_b64.find(",")
	if comma_pos >= 0:
		clean_b64 = clean_b64.substr(comma_pos + 1)
	clean_b64 = clean_b64.replace("\n", "").replace("\r", "").replace(" ", "")
	if clean_b64.is_empty():
		return
	var bytes := Marshalls.base64_to_raw(clean_b64)
	if bytes.is_empty():
		push_warning("[BackendSession] No se pudo decodificar avatar base64 (len=%d)" % clean_b64.length())
		return
	var ext := "png"
	if "jpeg" in mime_type or "jpg" in mime_type:
		ext = "jpg"
	elif "webp" in mime_type:
		ext = "webp"
	var path := SaveManager.guardar_avatar_bytes_vinculado(bytes, ext)
	if path.is_empty():
		return
	print("[BackendSession] Avatar descargado y guardado: ", path)
