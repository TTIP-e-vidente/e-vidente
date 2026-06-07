class_name ProgressSyncService
extends Node

signal sync_started()
signal sync_succeeded(progress: Dictionary)
signal sync_failed(reason: String)
signal pending_sync_started(count: int)
signal pending_sync_finished(synced_count: int, failed_count: int)
signal session_expired()

var _api_client: BackendApiClient = null
var _auth_session: AuthSession = null
var _reintentando_pendientes := false


func configurar(api_client: BackendApiClient, auth_session: AuthSession) -> void:
	_api_client = api_client
	_auth_session = auth_session


func esta_sincronizando() -> bool:
	return _reintentando_pendientes


func sincronizar(resumen_partida: Dictionary) -> Dictionary:
	if _api_client == null or _auth_session == null:
		push_error("[ProgressSyncService] configurar() no fue llamado antes de sincronizar()")
		return {}

	if not _auth_session.esta_logueado():
		return {}

	sync_started.emit()

	var response: Dictionary = await _api_client.guardar_progreso(
		_auth_session.obtener_token(),
		resumen_partida
	)

	if response.get("status", 0) == 401:
		_auth_session.limpiar_sesion()
		session_expired.emit()
		return response

	if not response.get("ok", false):
		var reason: String = response.get(
			"error",
			"Error del servidor (status %d)" % response.get("status", 0)
		)
		sync_failed.emit(reason)
		return response

	sync_succeeded.emit(response.get("data", {}))
	return response


func reintentar_pendientes(max_items: int = 10) -> void:
	if _api_client == null or _auth_session == null:
		return
	if _reintentando_pendientes or not _auth_session.esta_logueado():
		return

	_reintentando_pendientes = true
	var pending := LocalSyncQueue.listar_pendientes()
	var limit := mini(max_items, pending.size())
	if limit <= 0:
		_reintentando_pendientes = false
		return

	# Filtrar items inválidos antes de disparar requests
	var tareas: Array[Dictionary] = []
	var failed_count := 0
	for i in range(limit):
		var item: Dictionary = pending[i]
		var cid := str(item.get("clientRunId", "")).strip_edges()
		var payload: Dictionary = item.get("payload", {})
		if cid.is_empty() or payload.is_empty():
			failed_count += 1
			continue
		tareas.append({"cid": cid, "payload": payload})

	if tareas.is_empty():
		_reintentando_pendientes = false
		pending_sync_finished.emit(0, failed_count)
		return

	pending_sync_started.emit(tareas.size())

	var token := _auth_session.obtener_token()
	var synced_count := 0
	var sesion_expirada := false
	var resultados: Array[Dictionary] = []

	# Batch: un solo HTTP request para todos los ítems.
	var payloads: Array = []
	for tarea: Dictionary in tareas:
		payloads.append(tarea.payload)

	var batch_response: Dictionary = await _api_client.guardar_progreso_batch(token, payloads)

	if batch_response.get("status", 0) == 401:
		sesion_expirada = true
		for tarea: Dictionary in tareas:
			resultados.append({"id": tarea.cid, "ok": false, "error": "Sesion expirada"})
			failed_count += 1
	elif batch_response.get("ok", false):
		var data: Variant = batch_response.get("data", {})
		var batch_results: Variant = (
			(data as Dictionary).get("results", []) if data is Dictionary else []
		)
		# Indexar por clientRunId para aplicar resultados en orden de la cola.
		var by_cid: Dictionary = {}
		if batch_results is Array:
			for item: Variant in (batch_results as Array):
				if not item is Dictionary:
					continue
				var cid_key := str((item as Dictionary).get("clientRunId", ""))
				by_cid[cid_key] = item
		for tarea: Dictionary in tareas:
			var cid: String = tarea.cid
			var item_result: Variant = by_cid.get(cid, null)
			if item_result is Dictionary and bool((item_result as Dictionary).get("ok", false)):
				resultados.append({"id": cid, "ok": true})
				synced_count += 1
			else:
				var err := ""
				if item_result is Dictionary:
					err = str((item_result as Dictionary).get("error", ""))
				resultados.append({"id": cid, "ok": false, "error": err})
				failed_count += 1
	else:
		# Batch entero falló (ej: red caída, servidor no disponible).
		var reason := str(batch_response.get("error", "Batch sync fallido"))
		for tarea: Dictionary in tareas:
			resultados.append({"id": tarea.cid, "ok": false, "error": reason})
			failed_count += 1

	LocalSyncQueue.aplicar_resultados(resultados)

	if synced_count > 0:
		LocalSyncQueue.limpiar_cola()

	if sesion_expirada:
		_auth_session.limpiar_sesion()
		session_expired.emit()

	_reintentando_pendientes = false
	pending_sync_finished.emit(synced_count, failed_count)
