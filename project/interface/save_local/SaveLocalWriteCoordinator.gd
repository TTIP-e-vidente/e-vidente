extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func get_save_status() -> Dictionary:
	var raw_save_meta: Variant = _manager.save_data.get("save_meta", {})
	var save_meta: Dictionary = _manager._default_save_meta()
	if raw_save_meta is Dictionary:
		save_meta = raw_save_meta
	var active_session_summary: Dictionary = _manager.get_active_save_slot_summary()
	return {
		"state": str(_manager.runtime_save_status.get("state", "idle")),
		"last_saved_at": str(save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(save_meta.get("last_saved_reason", "")),
		"write_count": int(save_meta.get("write_count", 0)),
		"last_loaded_from": str(_manager.runtime_save_status.get("last_loaded_from", "default")),
		"recovered_from": str(_manager.runtime_save_status.get("recovered_from", "")),
		"last_error": str(_manager.runtime_save_status.get("last_error", "")),
		"has_unsaved_changes": _manager.has_unsaved_changes,
		"session_id": str(active_session_summary.get("id", "")),
		"session_title": str(active_session_summary.get("title", "")),
		"session_count": _manager.list_save_slots(true).size()
	}


func write_save_data(force: bool = false, reason: String = "save") -> bool:
	if not force and not _manager.has_unsaved_changes:
		return true

	_manager._ensure_active_session_for_write(reason)

	var payload: Dictionary = _manager.save_data.duplicate(true)
	var save_meta: Dictionary = _manager._normalize_save_meta(payload.get("save_meta", {}))
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = int(save_meta.get("write_count", 0)) + 1
	payload["save_meta"] = save_meta
	_manager.save_data["save_meta"] = save_meta
	_manager._sync_active_session_to_storage(save_meta)
	payload = _manager.save_data.duplicate(true)

	var serialized: String = JSON.stringify(payload, "\t")

	var temp_file := FileAccess.open(_manager.TEMP_SAVE_PATH, FileAccess.WRITE)
	if temp_file == null:
		emit_save_status("error", str(_manager.runtime_save_status.get("last_loaded_from", "default")), str(_manager.runtime_save_status.get("recovered_from", "")), "No se pudo abrir el archivo temporal del save.")
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null

	if FileAccess.file_exists(_manager.SAVE_PATH) and not _manager._copy_file(_manager.SAVE_PATH, _manager.BACKUP_SAVE_PATH):
		emit_save_status("error", str(_manager.runtime_save_status.get("last_loaded_from", "default")), str(_manager.runtime_save_status.get("recovered_from", "")), "No se pudo generar el backup del save local.")
		return false

	_manager._remove_file_if_exists(_manager.SAVE_PATH)
	if _manager._move_file(_manager.TEMP_SAVE_PATH, _manager.SAVE_PATH) != OK:
		if FileAccess.file_exists(_manager.BACKUP_SAVE_PATH):
			_manager._copy_file(_manager.BACKUP_SAVE_PATH, _manager.SAVE_PATH)
		emit_save_status("error", str(_manager.runtime_save_status.get("last_loaded_from", "default")), str(_manager.runtime_save_status.get("recovered_from", "")), "No se pudo reemplazar el save principal.")
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


func emit_save_status(state: String, loaded_from: String = "", recovered_from: String = "", last_error: String = "") -> void:
	_manager.runtime_save_status["state"] = state
	if not loaded_from.is_empty():
		_manager.runtime_save_status["last_loaded_from"] = loaded_from
	_manager.runtime_save_status["recovered_from"] = recovered_from
	_manager.runtime_save_status["last_error"] = last_error
	_manager._notify_save_status_changed()