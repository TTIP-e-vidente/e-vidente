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
		return {"ok": false, "status": 0, "error": "No active session"}

	var epoch := _auth_session.obtener_epoch()
	sync_started.emit()

	var response: Dictionary = await _api_client.guardar_progreso(
		_auth_session.obtener_token(),
		resumen_partida
	)

	if _auth_session.obtener_epoch() != epoch:
		# Logout o cambio de cuenta durante el POST: la respuesta es de la
		# sesión anterior; no tocar la sesión actual ni emitir señales.
		return {"ok": false, "status": 0, "error": "La sesión cambió durante la sincronización"}

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


const BATCH_CHUNK_SIZE := 50

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
		pending_sync_finished.emit(0, 0)
		return

	var tareas: Array[Dictionary] = []
	var failed_count := 0
	var usuario_actual := _auth_session.obtener_usuario().strip_edges()
	for i in range(limit):
		var item: Dictionary = pending[i]
		var owner := str(item.get("owner", "")).strip_edges()
		if not owner.is_empty() and owner != usuario_actual:
			# Partida de otra cuenta: queda en cola hasta que su dueño vuelva.
			continue
		var cid := str(item.get("clientRunId", "")).strip_edges()
		var payload: Dictionary = item.get("payload", {})
		if cid.is_empty() or payload.is_empty():
			LocalSyncQueue.marcar_fallido(cid, "payload o clientRunId vacío")
			failed_count += 1
			continue
		tareas.append({"cid": cid, "payload": payload})

	if tareas.is_empty():
		_reintentando_pendientes = false
		pending_sync_finished.emit(0, failed_count)
		return

	pending_sync_started.emit(tareas.size())

	var epoch := _auth_session.obtener_epoch()
	var token := _auth_session.obtener_token()
	var synced_count := 0
	var sesion_expirada := false
	var ultimo_summary: Dictionary = {}

	var chunk_start := 0
	while chunk_start < tareas.size():
		var chunk_end := mini(chunk_start + BATCH_CHUNK_SIZE, tareas.size())
		var chunk := tareas.slice(chunk_start, chunk_end)

		var payloads: Array = []
		for tarea: Dictionary in chunk:
			payloads.append(tarea.payload)

		var batch_response: Dictionary = await _api_client.guardar_progreso_batch(token, payloads)

		if _auth_session.obtener_epoch() != epoch:
			# Logout o cambio de cuenta durante el batch: no marcar la cola
			# ni aplicar el summary de la cuenta anterior al save actual.
			_reintentando_pendientes = false
			pending_sync_finished.emit(synced_count, failed_count)
			return

		var resultados: Array[Dictionary] = []

		if batch_response.get("status", 0) == 401:
			sesion_expirada = true
			# No incrementar attempts: la sesión expirada es transitoria
			break
		elif batch_response.get("ok", false):
			var data: Variant = batch_response.get("data", {})
			if data is Dictionary:
				# Estado consolidado (racha, nodos, exp) que el server calcula
				# una sola vez al final del batch.
				var ps: Variant = (data as Dictionary).get("progressSummary", {})
				if ps is Dictionary and not (ps as Dictionary).is_empty():
					ultimo_summary = ps as Dictionary
			var batch_results: Variant = (
				(data as Dictionary).get("results", []) if data is Dictionary else []
			)
			var by_cid: Dictionary = {}
			if batch_results is Array:
				for item: Variant in (batch_results as Array):
					if not item is Dictionary:
						continue
					var cid_key := str((item as Dictionary).get("clientRunId", ""))
					by_cid[cid_key] = item
			for tarea: Dictionary in chunk:
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
			var reason := str(batch_response.get("error", "Batch sync fallido"))
			for tarea: Dictionary in chunk:
				resultados.append({"id": tarea.cid, "ok": false, "error": reason})
				failed_count += 1

		LocalSyncQueue.aplicar_resultados(resultados)

		if sesion_expirada:
			break
		chunk_start = chunk_end

	if synced_count > 0:
		LocalSyncQueue.limpiar_cola()
		_aplicar_summary_batch(ultimo_summary)

	if sesion_expirada:
		_auth_session.limpiar_sesion()
		session_expired.emit()

	_reintentando_pendientes = false
	pending_sync_finished.emit(synced_count, failed_count)


func _aplicar_summary_batch(summary: Dictionary) -> void:
	if summary.is_empty() or SaveManager == null:
		return
	var cn_raw: Variant = summary.get("completedNodes", [])
	if cn_raw is Array and not (cn_raw as Array).is_empty():
		if SaveManager.has_method("fusionar_completados_desde_sync"):
			SaveManager.call("fusionar_completados_desde_sync", cn_raw as Array)
	var streak: Variant = summary.get("streak", {})
	if streak is Dictionary and not (streak as Dictionary).is_empty():
		SaveManager.aplicar_racha_sincronizada(streak as Dictionary)
	var profile: Variant = summary.get("profile", {})
	if profile is Dictionary:
		var server_exp := int((profile as Dictionary).get("exp_count", 0))
		if server_exp > SaveManager.obtener_exp_total():
			SaveManager.save_data["total_exp"] = server_exp
			SaveManager.guardar_progreso_en_disco()
