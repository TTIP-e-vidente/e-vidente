extends RefCounted

var _manager

func _init(manager):
	_manager = manager

func get_save_status() -> Dictionary:
	var raw_save_meta: Variant = _manager.save_data.get("save_meta", {})
	var save_meta: Dictionary = _data_normalizer().default_save_meta()
	if raw_save_meta is Dictionary:
		save_meta = _data_normalizer().normalize_save_meta(raw_save_meta)
	var active_save_summary: Dictionary = _manager.get_current_save_summary()
	var save_count: int = _manager.list_available_saves(true).size()
	return {
		"state": str(_manager.runtime_save_status.get("state", "idle")),
		"last_saved_at": str(save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(save_meta.get("last_saved_reason", "")),
		"write_count": int(save_meta.get("write_count", 0)),
		"last_loaded_from": str(_manager.runtime_save_status.get("last_loaded_from", "default")),
		"recovered_from": str(_manager.runtime_save_status.get("recovered_from", "")),
		"last_error": str(_manager.runtime_save_status.get("last_error", "")),
		"has_unsaved_changes": _manager.has_unsaved_changes,
		"save_id": str(active_save_summary.get("id", "")),
		"save_title": str(active_save_summary.get("title", "")),
		"save_count": save_count,
		"session_id": str(active_save_summary.get("id", "")),
		"session_title": str(active_save_summary.get("title", "")),
		"session_count": save_count
	}


func write_save_data(force: bool = false, reason: String = "save") -> bool:
	if not _should_write_to_disk(force):
		return true

	var save_meta: Dictionary = _build_updated_save_meta(reason)
	_manager.save_data["save_meta"] = save_meta
	var payload: Dictionary = _manager.save_data.duplicate(true)
	var serialized: String = _storage_helper().serialize_save_data(payload)
	if not _write_temp_save_file(serialized):
		return false
	if not _backup_existing_primary_save():
		return false
	if not _promote_temp_save_to_primary():
		return false

	_manager.save_data["save_meta"] = save_meta
	_manager.last_saved_snapshot = serialized
	_manager.has_unsaved_changes = false
	emit_save_status("saved", str(_manager.runtime_save_status.get("last_loaded_from", "default")))
	return true


func mark_dirty() -> void:
	if _manager.has_unsaved_changes:
		return
	_manager.has_unsaved_changes = true
	emit_save_status("dirty", str(_manager.runtime_save_status.get("last_loaded_from", "default")))


func emit_save_status(
	state: String,
	loaded_from: String = "",
	recovered_from: String = "",
	last_error: String = ""
) -> void:
	_manager.runtime_save_status["state"] = state
	if not loaded_from.is_empty():
		_manager.runtime_save_status["last_loaded_from"] = loaded_from
	_manager.runtime_save_status["recovered_from"] = recovered_from
	_manager.runtime_save_status["last_error"] = last_error
	_manager.notify_save_status_changed()


func _should_write_to_disk(force: bool) -> bool:
	return force or _manager.has_unsaved_changes


func _build_updated_save_meta(reason: String) -> Dictionary:
	var payload: Dictionary = _manager.save_data.duplicate(true)
	var save_meta: Dictionary = _data_normalizer().normalize_save_meta(payload.get("save_meta", {}))
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = int(save_meta.get("write_count", 0)) + 1
	return save_meta


func _write_temp_save_file(serialized: String) -> bool:
	var temp_file := FileAccess.open(_manager.TEMP_SAVE_PATH, FileAccess.WRITE)
	if temp_file == null:
		_emit_current_error("No se pudo abrir el archivo temporal del save.")
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null
	return true


func _backup_existing_primary_save() -> bool:
	if not FileAccess.file_exists(_manager.SAVE_PATH):
		return true
	if _should_preserve_existing_backup():
		return true
	if _storage_helper().copy_file(_manager.SAVE_PATH, _manager.BACKUP_SAVE_PATH):
		return true
	_emit_current_error("No se pudo generar el backup del save local.")
	return false


func _promote_temp_save_to_primary() -> bool:
	_storage_helper().remove_file_if_exists(_manager.SAVE_PATH)
	if _storage_helper().move_file(_manager.TEMP_SAVE_PATH, _manager.SAVE_PATH) == OK:
		_manager.runtime_save_status["recovered_from"] = ""
		return true
	if _can_keep_temp_snapshot_as_recovery_source():
		return true
	if FileAccess.file_exists(_manager.BACKUP_SAVE_PATH):
		_storage_helper().copy_file(_manager.BACKUP_SAVE_PATH, _manager.SAVE_PATH)
	_emit_current_error("No se pudo reemplazar el save principal.")
	return false


func _emit_current_error(message: String) -> void:
	emit_save_status(
		"error",
		str(_manager.runtime_save_status.get("last_loaded_from", "default")),
		str(_manager.runtime_save_status.get("recovered_from", "")),
		message
	)


func _should_preserve_existing_backup() -> bool:
	return str(_manager.runtime_save_status.get("last_loaded_from", "primary")) != "primary"


func _can_keep_temp_snapshot_as_recovery_source() -> bool:
	if not FileAccess.file_exists(_manager.TEMP_SAVE_PATH):
		return false
	return _should_preserve_existing_backup()


func _data_normalizer():
	return _manager.data_normalizer()


func _storage_helper():
	return _manager.storage_helper()
