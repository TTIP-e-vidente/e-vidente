class_name LocalSyncQueue
extends RefCounted

const QUEUE_PATH := "user://backend_sync_queue.json"
const QUEUE_BACKUP_PREFIX := "sync_queue_backup_"
const STATUS_PENDING := "pending"
const STATUS_SYNCED := "synced"
const STATUS_FAILED := "failed"
const MAX_ERROR_LENGTH := 500
const MAX_ATTEMPTS := 5

static var _cache: Dictionary = {}
static var _cache_valid: bool = false


## [param owner]: username de la cuenta logueada al jugar la partida ("" si offline).
## Permite archivar/restaurar los pendientes por usuario al cambiar de cuenta,
## en vez de descartarlos (descartar rompía la racha del server: esos días
## nunca llegaban a sincronizarse).
static func encolar_resumen_partida(resumen: Dictionary, owner: String = "") -> void:
	var client_run_id := str(resumen.get("clientRunId", "")).strip_edges()
	if client_run_id.is_empty():
		push_warning("[LocalSyncQueue] RunSummary sin clientRunId; no se encola.")
		return

	var queue := _cargar_cola()
	var items: Array = queue.get("items", [])
	for item: Variant in items:
		if item is Dictionary and str((item as Dictionary).get("clientRunId", "")) == client_run_id:
			return

	items.append({
		"clientRunId": client_run_id,
		"owner": owner.strip_edges(),
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
	var items: Array = _cargar_cola().get("items", [])
	var result: Array[Dictionary] = []
	for item: Variant in items:
		if not item is Dictionary:
			continue
		if str((item as Dictionary).get("status", STATUS_PENDING)) == STATUS_PENDING:
			result.append(item as Dictionary)
	return result


static func contar_pendientes() -> int:
	var count: int = 0
	for item: Variant in _cargar_cola().get("items", []):
		if item is Dictionary and str((item as Dictionary).get("status", STATUS_PENDING)) == STATUS_PENDING:
			count += 1
	return count


static func marcar_sincronizado(client_run_id: String) -> void:
	_actualizar_item(client_run_id, func(item: Dictionary) -> void:
		item["status"] = STATUS_SYNCED
		item["syncedAt"] = Time.get_datetime_string_from_system(true)
		item["lastError"] = ""
	)


static func marcar_fallido(client_run_id: String, error: String) -> void:
	_actualizar_item(client_run_id, func(item: Dictionary) -> void:
		var new_attempts: int = int(item.get("attempts", 0)) + 1
		item["attempts"] = new_attempts
		item["lastError"] = error.substr(0, MAX_ERROR_LENGTH)
		item["status"] = STATUS_FAILED if new_attempts >= MAX_ATTEMPTS else STATUS_PENDING
	)


static func descartar_pendientes(reason: String) -> void:
	var queue: Dictionary = _cargar_cola()
	var items: Array = queue.get("items", [])
	var changed := false
	for raw_item: Variant in items:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item as Dictionary
		if str(item.get("status", STATUS_PENDING)) != STATUS_PENDING:
			continue
		item["status"] = STATUS_FAILED
		item["lastError"] = reason.substr(0, MAX_ERROR_LENGTH)
		item["attempts"] = MAX_ATTEMPTS
		changed = true
	if changed:
		_guardar_cola(queue)


## Mueve los ítems PENDING del usuario a su archivo de backup. Se usa al cambiar
## de cuenta: las partidas sin sincronizar del usuario saliente se preservan
## y vuelven a la cola cuando ese usuario inicie sesión de nuevo.
static func archivar_pendientes_de_usuario(owner: String) -> int:
	var clean_owner := owner.strip_edges()
	if clean_owner.is_empty():
		return 0

	var queue: Dictionary = _cargar_cola()
	var items: Array = queue.get("items", [])
	var a_archivar: Array = []
	var restantes: Array = []
	for raw_item: Variant in items:
		var es_del_usuario := (
			raw_item is Dictionary
			and str((raw_item as Dictionary).get("status", STATUS_PENDING)) == STATUS_PENDING
			and str((raw_item as Dictionary).get("owner", "")).strip_edges() == clean_owner
		)
		if es_del_usuario:
			a_archivar.append(raw_item)
		else:
			restantes.append(raw_item)

	if a_archivar.is_empty():
		return 0

	var backup: Array = _leer_backup_cola(clean_owner)
	backup.append_array(a_archivar)
	if not _escribir_backup_cola(clean_owner, backup):
		push_warning("[LocalSyncQueue] No se pudo archivar pendientes de ", clean_owner)
		return 0

	queue["items"] = restantes
	_guardar_cola(queue)
	print("[LocalSyncQueue] Archivados ", a_archivar.size(), " pendientes de ", clean_owner)
	return a_archivar.size()


## Re-encola los ítems archivados del usuario (si los hay) y borra su backup.
static func restaurar_pendientes_de_usuario(owner: String) -> int:
	var clean_owner := owner.strip_edges()
	if clean_owner.is_empty():
		return 0

	var backup: Array = _leer_backup_cola(clean_owner)
	if backup.is_empty():
		return 0

	var queue: Dictionary = _cargar_cola()
	var items: Array = queue.get("items", [])
	var ids_existentes: Dictionary = {}
	for raw_item: Variant in items:
		if raw_item is Dictionary:
			ids_existentes[str((raw_item as Dictionary).get("clientRunId", ""))] = true

	var restaurados := 0
	for raw_item: Variant in backup:
		if not raw_item is Dictionary:
			continue
		var cid := str((raw_item as Dictionary).get("clientRunId", ""))
		if cid.is_empty() or ids_existentes.has(cid):
			continue
		items.append(raw_item)
		restaurados += 1

	if restaurados > 0:
		queue["items"] = items
		_guardar_cola(queue)
	_borrar_backup_cola(clean_owner)
	if restaurados > 0:
		print("[LocalSyncQueue] Restaurados ", restaurados, " pendientes de ", clean_owner)
	return restaurados


static func _ruta_backup_cola(owner: String) -> String:
	var safe_name := owner.strip_edges().to_lower().replace("/", "_").replace("\\", "_")
	return "user://" + QUEUE_BACKUP_PREFIX + safe_name + ".json"


static func _leer_backup_cola(owner: String) -> Array:
	var path := _ruta_backup_cola(owner)
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Array if parsed is Array else []


static func _escribir_backup_cola(owner: String, items: Array) -> bool:
	var file := FileAccess.open(_ruta_backup_cola(owner), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(items, "\t"))
	file.close()
	return true


static func _borrar_backup_cola(owner: String) -> void:
	var path := _ruta_backup_cola(owner)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func aplicar_resultados(resultados: Array[Dictionary]) -> void:
	if resultados.is_empty():
		return
	var queue: Dictionary = _cargar_cola()
	var items: Array = queue.get("items", [])
	for resultado: Dictionary in resultados:
		var id: String = str(resultado.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		for raw_item: Variant in items:
			if not raw_item is Dictionary:
				continue
			var item: Dictionary = raw_item as Dictionary
			if str(item.get("clientRunId", "")) != id:
				continue
			if resultado.get("ok", false):
				item["status"] = STATUS_SYNCED
				item["syncedAt"] = Time.get_datetime_string_from_system(true)
				item["lastError"] = ""
			else:
				var new_attempts: int = int(item.get("attempts", 0)) + 1
				item["attempts"] = new_attempts
				item["lastError"] = str(resultado.get("error", "")).substr(0, MAX_ERROR_LENGTH)
				item["status"] = STATUS_FAILED if new_attempts >= MAX_ATTEMPTS else STATUS_PENDING
			break
	_guardar_cola(queue)


static func limpiar_cola(dias_sync: int = 7, dias_fallido: int = 30) -> void:
	var now := Time.get_unix_time_from_system()
	var cutoff_sync := now - float(dias_sync * 24 * 60 * 60)
	var cutoff_fallido := now - float(dias_fallido * 24 * 60 * 60)
	var queue := _cargar_cola()
	var kept: Array = []
	for raw: Variant in queue.get("items", []):
		if not raw is Dictionary:
			continue
		var item := raw as Dictionary
		var status := str(item.get("status", ""))
		if status == STATUS_SYNCED:
			var synced_at := str(item.get("syncedAt", "")).strip_edges()
			if not synced_at.is_empty():
				if Time.get_unix_time_from_datetime_string(synced_at) < cutoff_sync:
					continue
		elif status == STATUS_FAILED:
			var created_at := str(item.get("createdAt", "")).strip_edges()
			if not created_at.is_empty():
				if Time.get_unix_time_from_datetime_string(created_at) < cutoff_fallido:
					continue
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
	for item: Variant in items:
		if item is Dictionary and str((item as Dictionary).get("clientRunId", "")) == clean_id:
			aplicar_cambio.call(item as Dictionary)
			changed = true
			break
	if changed:
		_guardar_cola(queue)


static func _cargar_cola() -> Dictionary:
	if _cache_valid:
		return _cache

	if not FileAccess.file_exists(QUEUE_PATH):
		_cache = {"items": []}
		_cache_valid = true
		return _cache

	var file := FileAccess.open(QUEUE_PATH, FileAccess.READ)
	if file == null:
		_cache = {"items": []}
		_cache_valid = true
		return _cache

	var raw := file.get_as_text()
	file.close()

	if raw.strip_edges().is_empty():
		_cache = {"items": []}
		_cache_valid = true
		return _cache

	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_cache = parsed as Dictionary
		if not _cache.get("items", []) is Array:
			_cache["items"] = []
		_cache_valid = true
		return _cache

	_respaldar_cola_corrupta(raw)
	_cache = {"items": []}
	_cache_valid = true
	return _cache


static func _guardar_cola(queue: Dictionary) -> void:
	var file := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[LocalSyncQueue] No se pudo escribir %s — cache NO actualizado" % QUEUE_PATH)
		return
	file.store_string(JSON.stringify(queue, "\t"))
	file.close()
	# Actualizar cache SOLO después de confirmar que el disco tuvo éxito.
	# Si se actualiza antes y el open falla, el cache queda desincronizado del disco
	# y los ítems encolados se pierden silenciosamente al reiniciar el juego.
	_cache = queue
	_cache_valid = true


static func _respaldar_cola_corrupta(raw: String) -> void:
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var backup_path := "user://backend_sync_queue_corrupt_%s.json" % stamp
	var file := FileAccess.open(backup_path, FileAccess.WRITE)
	if file == null:
		push_warning("[LocalSyncQueue] Cola corrupta; no se pudo crear backup.")
		return
	file.store_string(raw)
	file.close()
