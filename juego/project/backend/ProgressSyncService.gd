class_name ProgressSyncService
extends Node

signal sync_started()

signal sync_succeeded(progress: Dictionary)
signal sync_failed(reason: String)

## Emitida cuando el backend devuelve 401 (token vencido o inválido).
## La sesión queda borrada automáticamente.
signal session_expired()

var _api_client: BackendApiClient = null
var _auth_session: AuthSession = null


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
