class_name LocalSyncQueue
extends RefCounted

const QUEUE_PATH := "user://backend_sync_queue.json"
const STATUS_PENDING := "pending"
const STATUS_SYNCED := "synced"
const MAX_ERROR_LENGTH := 500


static func encolar_resumen_partida(resumen: Dictionary) -> void:
	var client_run_id := str(resumen.get("clientRunId", "")).strip_edges()
	if client_run_id.is_empty():
		push_warning("[LocalSyncQueue] RunSummary sin clientRunId; no se encola.")
		return

	var queue := _cargar_cola()
	var items: Array = queue.get("items", [])
	for item in items:
		if item is Dictionary and str(item.get("clientRunId", "")) == client_run_id:
			return

	items.append({
		"clientRunId": client_run_id,
		"status": STATUS_PENDING,
		"attempts": 0,
		"lastError": "",
		"createdAt": Time.get_datetime_string_from_system(true),
		"syncedAt": "",
		"payload": resumen.duplicate(true),
	})
	queue["items"] = items
	_guardar_cola(queue)


static func listar_pendientes() -> Array[Dictionary]:
	var queue := _cargar_cola()
	var result: Array[Dictionary] = []
	var items: Array = queue.get("items", [])
	for item in items:
		if not item is Dictionary:
			continue
		var status := str(item.get("status", STATUS_PENDING))
		if status == STATUS_PENDING:
			result.append((item as Dictionary).duplicate(true))
	return result


static func marcar_sincronizado(client_run_id: String) -> void:
	_actualizar_item(client_run_id, func(item: Dictionary) -> void:
		item["status"] = STATUS_SYNCED
		item["syncedAt"] = Time.get_datetime_string_from_system(true)
		item["lastError"] = ""
	)


static func marcar_fallido(client_run_id: String, error: String) -> void:
	_actualizar_item(client_run_id, func(item: Dictionary) -> void:
		item["status"] = STATUS_PENDING
		item["attempts"] = int(item.get("attempts", 0)) + 1
		item["lastError"] = error.substr(0, MAX_ERROR_LENGTH)
	)


static func eliminar_sincronizados_mas_viejos_que(dias: int) -> void:
	if dias < 1:
		return
	var cutoff_unix := Time.get_unix_time_from_system() - float(dias * 24 * 60 * 60)
	var queue := _cargar_cola()
	var kept: Array = []
	for item in queue.get("items", []):
		if not item is Dictionary:
			continue
		var synced_at := str(item.get("syncedAt", "")).strip_edges()
		if str(item.get("status", "")) != STATUS_SYNCED or synced_at.is_empty():
			kept.append(item)
			continue
		var synced_unix := Time.get_unix_time_from_datetime_string(synced_at)
		if synced_unix >= cutoff_unix:
			kept.append(item)
	queue["items"] = kept
	_guardar_cola(queue)


static func _actualizar_item(client_run_id: String, aplicar_cambio: Callable) -> void:
	var clean_id := client_run_id.strip_edges()
	if clean_id.is_empty():
		return
	var queue := _cargar_cola()
	var items: Array = queue.get("items", [])
	var changed := false
	for item in items:
		if item is Dictionary and str(item.get("clientRunId", "")) == clean_id:
			aplicar_cambio.call(item)
			changed = true
			break
	if changed:
		queue["items"] = items
		_guardar_cola(queue)


static func _cargar_cola() -> Dictionary:
	if not FileAccess.file_exists(QUEUE_PATH):
		return {"items": []}

	var file := FileAccess.open(QUEUE_PATH, FileAccess.READ)
	if file == null:
		return {"items": []}
	var raw := file.get_as_text()
	file.close()
	if raw.strip_edges().is_empty():
		return {"items": []}

	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		var queue: Dictionary = parsed
		if not queue.get("items", []) is Array:
			queue["items"] = []
		return queue

	_respaldar_cola_corrupta(raw)
	return {"items": []}


static func _guardar_cola(queue: Dictionary) -> void:
	var file := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[LocalSyncQueue] No se pudo escribir %s" % QUEUE_PATH)
		return
	file.store_string(JSON.stringify(queue, "\t"))
	file.close()


static func _respaldar_cola_corrupta(raw: String) -> void:
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var backup_path := "user://backend_sync_queue_corrupt_%s.json" % stamp
	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		push_warning("[LocalSyncQueue] Cola corrupta; no se pudo crear backup.")
		return
	file.store_string(raw)
	file.close()
