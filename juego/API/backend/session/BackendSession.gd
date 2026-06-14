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
# Epoch de la sesión al que pertenecen la carga en curso y el último resultado.
# Evita que una carga de la cuenta anterior (en vuelo durante logout/login)
# pise el cache o el save local de la cuenta nueva.
var _epoch_carga_en_curso: int = -1
var _epoch_ultimo_resultado: int = -1
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

	var resultado_progreso: Dictionary = await obtener_progreso_del_servidor()
	if not resultado_progreso.get("ok", false):
		return resultado_progreso
	if _auth.obtener_epoch() != epoch:
		return _resultado_sesion_cambiada()

	var datos_usuario: Dictionary = resultado_usuario.get("data", {})
	var datos_progreso: Dictionary = resultado_progreso.get("data", {})
	var username_sync := str(_auth.obtener_usuario()).strip_edges()
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
	# Fire-and-forget: descarga el avatar del backend si no hay uno local.
	_descargar_avatar_si_falta(epoch)
	if LocalSyncQueue.contar_pendientes() > 0 and not _sync.esta_sincronizando():
		_sync.reintentar_pendientes()

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


func subir_avatar(base64_data: String, mime_type: String) -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.subir_avatar(_auth.obtener_token(), base64_data, mime_type)
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


func eliminar_avatar_online() -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "error": "No active session"}
	var epoch := _auth.obtener_epoch()
	var resultado := await _api.eliminar_avatar(_auth.obtener_token())
	_verificar_sesion_expirada(resultado, epoch)
	return resultado


func actualizar_perfil_online(nombre: String, mail: String, fecha_nacimiento: String) -> Dictionary:
	if not _auth.esta_logueado():
		return {"ok": false, "error": "No active session"}

	var clean_name := nombre.strip_edges()
	if clean_name.is_empty():
		clean_name = obtener_usuario()

	var payload := {
		"name": clean_name,
	}

	var clean_mail := mail.strip_edges()
	if not clean_mail.is_empty():
		payload["mail"] = clean_mail

	var clean_birth := fecha_nacimiento.strip_edges()
	if not clean_birth.is_empty():
		payload["birth_date"] = clean_birth

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
			_usuario_en_cache = user_data as Dictionary
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
	var timed_out := false
	timer.timeout.connect(func(): timed_out = true, CONNECT_ONE_SHOT)
	while not timed_out and _sync.esta_sincronizando():
		await get_tree().process_frame
	if timed_out:
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
	_descartar_resultado_carga_online()
	logout_completed.emit()


func _descartar_resultado_carga_online() -> void:
	_ultimo_resultado_carga_online = {}
	_epoch_ultimo_resultado = -1


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
	_descartar_resultado_carga_online()
	_auth.establecer_sesion(access_token, username)
	if SaveManager != null and SaveManager.has_method("preparar_cuenta_online"):
		SaveManager.call("preparar_cuenta_online", user)
	BackendSessionStorage.guardar_sesion(access_token, username, user)
	login_succeeded.emit(user)


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

	_auth.establecer_sesion(token, username)
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
		_auth.establecer_sesion(token, username_fresco)
		if SaveManager != null and SaveManager.has_method("preparar_cuenta_online"):
			SaveManager.call("preparar_cuenta_online", user)
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
	SaveManager.sincronizar_con_cuenta_online(_usuario_en_cache, _progreso_online_en_cache)


func _descargar_avatar_si_falta(epoch: int) -> void:
	if SaveManager == null or not _auth.esta_logueado():
		return

	var local_path := SaveManager.obtener_ruta_avatar_usuario_actual()
	if not local_path.is_empty() and not SaveManager.es_ruta_avatar_vinculada(local_path):
		SaveManager.limpiar_avatar_perfil()
		local_path = ""

	var resultado := await _api.descargar_avatar(_auth.obtener_token())
	if _auth.obtener_epoch() != epoch:
		# Cambió la cuenta mientras se descargaba: no guardar el avatar
		# de la cuenta anterior bajo la clave de la nueva.
		return
	if not bool(resultado.get("ok", false)):
		return
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
