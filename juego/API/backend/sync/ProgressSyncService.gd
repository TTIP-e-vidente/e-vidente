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

	pending_sync_started.emit(limit)
	var synced_count := 0
	var failed_count := 0

	for index in range(limit):
		var item: Dictionary = pending[index]
		var client_run_id := str(item.get("clientRunId", "")).strip_edges()
		var payload: Dictionary = item.get("payload", {})
		if client_run_id.is_empty() or payload.is_empty():
			continue

		var response: Dictionary = await _api_client.guardar_progreso(
			_auth_session.obtener_token(),
			payload
		)

		if response.get("status", 0) == 401:
			_auth_session.limpiar_sesion()
			session_expired.emit()
			failed_count += 1
			LocalSyncQueue.marcar_fallido(client_run_id, "Sesion expirada")
			break

		if response.get("ok", false):
			LocalSyncQueue.marcar_sincronizado(client_run_id)
			synced_count += 1
		else:
			var reason := str(response.get("error", "Sync pendiente fallida"))
			LocalSyncQueue.marcar_fallido(client_run_id, reason)
			failed_count += 1

	_reintentando_pendientes = false
	pending_sync_finished.emit(synced_count, failed_count)
