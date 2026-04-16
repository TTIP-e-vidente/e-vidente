extends RefCounted

var _save_manager

func _init(save_manager):
	_save_manager = save_manager

func get_save_status() -> Dictionary:
	var stored_save_metadata: Variant = _save_manager.save_data.get("save_meta", {})
	var save_metadata: Dictionary = _get_save_data_normalizer().default_save_meta()
	if stored_save_metadata is Dictionary:
		save_metadata = _get_save_data_normalizer().normalize_save_meta(stored_save_metadata)
	var local_save_summary: Dictionary = _save_manager.get_current_save_summary()
	var available_save_count: int = _save_manager.list_available_saves(true).size()
	return {
		"state": str(_save_manager.runtime_save_status.get("state", "idle")),
		"last_saved_at": str(save_metadata.get("last_saved_at", "")),
		"last_saved_reason": str(save_metadata.get("last_saved_reason", "")),
		"write_count": int(save_metadata.get("write_count", 0)),
		"last_loaded_from": str(
			_save_manager.runtime_save_status.get("last_loaded_from", "default")
		),
		"recovered_from": str(_save_manager.runtime_save_status.get("recovered_from", "")),
		"last_error": str(_save_manager.runtime_save_status.get("last_error", "")),
		"has_unsaved_changes": _save_manager.has_unsaved_changes,
		"save_id": str(local_save_summary.get("id", "")),
		"save_title": str(local_save_summary.get("title", "")),
		"save_count": available_save_count,
		"session_id": str(local_save_summary.get("id", "")),
		"session_title": str(local_save_summary.get("title", "")),
		"session_count": available_save_count
	}


func write_save_data(force: bool = false, reason: String = "save") -> bool:
	if not _should_write_to_disk(force):
		return true

	var save_metadata: Dictionary = _build_updated_save_metadata(reason)
	_save_manager.save_data["save_meta"] = save_metadata
	var save_payload: Dictionary = _save_manager.save_data.duplicate(true)
	var serialized_payload: String = _get_storage_helper().serialize_save_data(save_payload)
	if not _write_temp_save_snapshot(serialized_payload):
		return false
	if not _backup_primary_save_if_needed():
		return false
	if not _replace_primary_save_with_temp():
		return false

	_save_manager.save_data["save_meta"] = save_metadata
	_save_manager.last_saved_snapshot = serialized_payload
	_save_manager.has_unsaved_changes = false
	emit_save_status(
		"saved",
		str(_save_manager.runtime_save_status.get("last_loaded_from", "default"))
	)
	return true


func mark_dirty() -> void:
	if _save_manager.has_unsaved_changes:
		return
	_save_manager.has_unsaved_changes = true
	emit_save_status(
		"dirty",
		str(_save_manager.runtime_save_status.get("last_loaded_from", "default"))
	)


func emit_save_status(
	state: String,
	loaded_from: String = "",
	recovered_from: String = "",
	last_error: String = ""
) -> void:
	_save_manager.runtime_save_status["state"] = state
	if not loaded_from.is_empty():
		_save_manager.runtime_save_status["last_loaded_from"] = loaded_from
	_save_manager.runtime_save_status["recovered_from"] = recovered_from
	_save_manager.runtime_save_status["last_error"] = last_error
	_save_manager.notify_save_status_changed()


func _should_write_to_disk(force: bool) -> bool:
	return force or _save_manager.has_unsaved_changes


func _build_updated_save_metadata(reason: String) -> Dictionary:
	var save_payload: Dictionary = _save_manager.save_data.duplicate(true)
	var save_metadata: Dictionary = _get_save_data_normalizer().normalize_save_meta(
		save_payload.get("save_meta", {})
	)
	save_metadata["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_metadata["last_saved_reason"] = reason
	save_metadata["write_count"] = int(save_metadata.get("write_count", 0)) + 1
	return save_metadata


func _write_temp_save_snapshot(serialized_payload: String) -> bool:
	var temp_file := FileAccess.open(_save_manager.TEMP_SAVE_PATH, FileAccess.WRITE)
	if temp_file == null:
		_publish_write_error("No se pudo abrir el archivo temporal del save.")
		return false
	temp_file.store_string(serialized_payload)
	temp_file.flush()
	temp_file = null
	return true


func _backup_primary_save_if_needed() -> bool:
	if not FileAccess.file_exists(_save_manager.SAVE_PATH):
		return true
	if _should_keep_existing_backup():
		return true
	if _get_storage_helper().copy_file(_save_manager.SAVE_PATH, _save_manager.BACKUP_SAVE_PATH):
		return true
	_publish_write_error("No se pudo generar el backup del save local.")
	return false


func _replace_primary_save_with_temp() -> bool:
	_get_storage_helper().remove_file_if_exists(_save_manager.SAVE_PATH)
	if _get_storage_helper().move_file(_save_manager.TEMP_SAVE_PATH, _save_manager.SAVE_PATH) == OK:
		_save_manager.runtime_save_status["recovered_from"] = ""
		return true
	if _can_leave_temp_save_as_recovery_source():
		return true
	if FileAccess.file_exists(_save_manager.BACKUP_SAVE_PATH):
		_get_storage_helper().copy_file(_save_manager.BACKUP_SAVE_PATH, _save_manager.SAVE_PATH)
	_publish_write_error("No se pudo reemplazar el save principal.")
	return false


func _publish_write_error(message: String) -> void:
	emit_save_status(
		"error",
		str(_save_manager.runtime_save_status.get("last_loaded_from", "default")),
		str(_save_manager.runtime_save_status.get("recovered_from", "")),
		message
	)


func _should_keep_existing_backup() -> bool:
	return str(_save_manager.runtime_save_status.get("last_loaded_from", "primary")) != "primary"


func _can_leave_temp_save_as_recovery_source() -> bool:
	if not FileAccess.file_exists(_save_manager.TEMP_SAVE_PATH):
		return false
	return _should_keep_existing_backup()


func _get_save_data_normalizer():
	return _save_manager.get_save_data_normalizer()


func _get_storage_helper():
	return _save_manager.get_storage_helper()
