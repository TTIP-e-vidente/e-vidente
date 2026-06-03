## ProgressSyncService: sync y retry
## Servicio de sincronización de progreso.
## Envía summaries al backend usando BackendSession.
## Marca pending/synced/failed.
## Reintenta pendientes al restaurar sesión.
class_name ProgressSyncService
extends Node

signal sync_started()

signal sync_succeeded(progress: Dictionary)
signal sync_failed(reason: String)
signal pending_sync_started(count: int)
signal pending_sync_finished(synced_count: int, failed_count: int)

## Emitida cuando el backend devuelve 401 (token vencido o inválido).
## La sesión queda borrada automáticamente.
signal session_expired()

var _api_client: BackendApiClient = null
var _auth_session: AuthSession = null
var _is_retrying_pending := false


## Inyecta las dependencias. Llamar una sola vez antes de usar sync().
func setup(api_client: BackendApiClient, auth_session: AuthSession) -> void:
	_api_client = api_client
	_auth_session = auth_session

func sync(run_summary: Dictionary) -> Dictionary:
	if _api_client == null or _auth_session == null:
		push_error("[ProgressSyncService] setup() no fue llamado antes de sync()")
		return {}

	if not _auth_session.is_logged_in():
		# Modo offline: salir silenciosamente sin romper el flujo
		return {}

	sync_started.emit()

	var response: Dictionary = await _api_client.save_progress(
		_auth_session.get_token(),
		run_summary
	)

	if response.get("status", 0) == 401:
		_auth_session.clear_session()
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


func retry_pending(max_items: int = 10) -> void:
	if _api_client == null or _auth_session == null:
		return
	if _is_retrying_pending or not _auth_session.is_logged_in():
		return

	_is_retrying_pending = true
	var pending := LocalSyncQueue.list_pending()
	var limit := mini(max_items, pending.size())
	if limit <= 0:
		_is_retrying_pending = false
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

		var response: Dictionary = await _api_client.save_progress(
			_auth_session.get_token(),
			payload
		)

		if response.get("status", 0) == 401:
			_auth_session.clear_session()
			session_expired.emit()
			failed_count += 1
			LocalSyncQueue.mark_failed(client_run_id, "Sesion expirada")
			break

		if response.get("ok", false):
			LocalSyncQueue.mark_synced(client_run_id)
			synced_count += 1
		else:
			var reason := str(response.get("error", "Sync pendiente fallida"))
			LocalSyncQueue.mark_failed(client_run_id, reason)
			failed_count += 1

	_is_retrying_pending = false
	pending_sync_finished.emit(synced_count, failed_count)
