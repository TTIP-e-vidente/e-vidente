# Autoload interno. Desde el juego usar AuthApi y SyncApi.
extends Node

const BACKGROUND_SYNC_INTERVAL_SECS := 300.0  # 5 minutos

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

var _api: BackendApiClient
var _auth: AuthSession
var _sync: ProgressSyncService
var _usuario_en_cache: Dictionary = {}
var _progreso_online_en_cache: Dictionary = {}
var _carga_online_en_curso: bool = false
var _ultimo_resultado_carga_online: Dictionary = {}
# Dirty-flag: si llega un trigger mientras el sync corre, lo re-ejecuta al terminar.
var _reintento_encolado: bool = false


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


func esta_logueado() -> bool:
	return _auth.esta_logueado()


func obtener_token() -> String:
	return _auth.obtener_token()


func obtener_usuario() -> String:
	return _auth.obtener_usuario()


func obtener_usuario_en_cache() -> Dictionary:
	return _usuario_en_cache


func obtener_progreso_online_en_cache() -> Dictionary:
	return _progreso_online_en_cache


func tiene_datos_online_en_memoria() -> bool:
	return not _usuario_en_cache.is_empty()


func limpiar_cache_online() -> void:
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()


func cargar_datos_online() -> Dictionary:
	if _carga_online_en_curso:
		while _carga_online_en_curso:
			await get_tree().process_frame
		return _ultimo_resultado_carga_online.duplicate(true)

	_carga_online_en_curso = true
	_ultimo_resultado_carga_online = await _cargar_datos_online_interno()
	_carga_online_en_curso = false
	return _ultimo_resultado_carga_online.duplicate(true)


func _cargar_datos_online_interno() -> Dictionary:
	if not esta_logueado():
		return {
			"ok": false,
			"status": 401,
			"error": "No active session"
		}

	var resultado_usuario: Dictionary = await obtener_usuario_del_servidor()
	if not resultado_usuario.get("ok", false):
		return resultado_usuario

	var resultado_progreso: Dictionary = await obtener_progreso_del_servidor()
	if not resultado_progreso.get("ok", false):
		return resultado_progreso

	var datos_usuario: Dictionary = resultado_usuario.get("data", {})
	var datos_progreso: Dictionary = resultado_progreso.get("data", {})

	_usuario_en_cache = datos_usuario.get("user", datos_usuario)
	_progreso_online_en_cache = datos_progreso
	_aplicar_progreso_online_al_save_local()

	return {
		"ok": true,
		"status": 200,
		"user": _usuario_en_cache,
		"progress": _progreso_online_en_cache
	}


func verificar_estado_del_servidor() -> Dictionary:
	var salud_api := await _api.verificar_salud_api()
	if not salud_api.get("ok", false):
		return {"ok": false, "phase": "api", "result": salud_api}
	var salud_db := await _api.verificar_salud_db()
	if not salud_db.get("ok", false):
		return {"ok": false, "phase": "db", "result": salud_db}
	return {"ok": true}


func iniciar_sesion(usuario_o_mail: String, clave: String) -> Dictionary:
	var listo := await _asegurar_servidor_listo()
	if not listo.get("ok", false):
		return listo
	var resultado := await _api.iniciar_sesion(usuario_o_mail, clave)
	_procesar_resultado_de_auth(resultado)
	return resultado


func registrar_cuenta(
	usuario: String,
	nombre: String,
	mail: String,
	clave: String,
	fecha_nacimiento: Variant = null
) -> Dictionary:
	var listo := await _asegurar_servidor_listo()
	if not listo.get("ok", false):
		return listo
	var resultado := await _api.registrar_cuenta(usuario, nombre, mail, clave, fecha_nacimiento)
	_procesar_resultado_de_auth(resultado)
	return resultado


func obtener_usuario_del_servidor() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	return await _api.obtener_mi_usuario(_auth.obtener_token())


func obtener_progreso_del_servidor() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 401, "error": "No active session"}
	return await _api.obtener_progreso(_auth.obtener_token())


func guardar_progreso_online(resumen_partida: Dictionary) -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "status": 0, "error": "No active session"}
	var resultado := await _sync.sincronizar(resumen_partida)
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


func _al_sync_pendientes_terminado(synced: int, failed: int) -> void:
	pending_sync_finished.emit(synced, failed)
	if _reintento_encolado:
		_reintento_encolado = false
		if _auth.esta_logueado() and LocalSyncQueue.contar_pendientes() > 0:
			_sync.reintentar_pendientes()


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
	logout_completed.emit()


func _asegurar_servidor_listo() -> Dictionary:
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
	_auth.establecer_sesion(access_token, username)
	BackendSessionStorage.guardar_sesion(access_token, username, user)
	login_succeeded.emit(user)
	_sync.reintentar_pendientes()


func _al_expirar_sesion() -> void:
	_auth.limpiar_sesion()
	BackendSessionStorage.borrar_sesion()
	_usuario_en_cache.clear()
	_progreso_online_en_cache.clear()
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

	_auth.establecer_sesion(token, username)

	var resultado := await obtener_usuario_del_servidor()
	if resultado.get("ok", false):
		var data: Dictionary = resultado.get("data", {})
		var user: Dictionary = data.get("user", data)
		var username_fresco: String = user.get("username", username)
		_auth.establecer_sesion(token, username_fresco)
		print("[BackendSession] Sesión restaurada: ", username_fresco)
		session_restored.emit(user)
		await cargar_datos_online()
		_sync.reintentar_pendientes()
	else:
		print("[BackendSession] Token inválido o expirado — limpiando sesión local.")
		_auth.limpiar_sesion()
		BackendSessionStorage.borrar_sesion()
		session_restore_failed.emit(str(resultado.get("error", "Sesión inválida")))


func _aplicar_progreso_online_al_save_local() -> void:
	if _usuario_en_cache.is_empty() or _progreso_online_en_cache.is_empty():
		return
	if SaveManager == null:
		return
	SaveManager.sincronizar_con_cuenta_online(_usuario_en_cache, _progreso_online_en_cache)
