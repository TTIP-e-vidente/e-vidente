extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func load_data() -> void:
	var load_context: Dictionary = _restore_save_data_from_disk()
	_prepare_runtime_after_load(load_context)
	_finalize_load_status(load_context)
	Global.import_progress(_manager.save_data.get("progress", {}))


func _restore_save_data_from_disk() -> Dictionary:
	_manager.save_data = _data_normalizer().default_save_data()
	var load_result: Dictionary = _storage_helper().load_available_save_data(
		_manager.SAVE_PATH,
		_manager.TEMP_SAVE_PATH,
		_manager.BACKUP_SAVE_PATH
	)
	var loaded_from: String = "default"
	var recovered_from: String = ""
	var needs_write: bool = false
	var rewrite_reason: String = ""

	if bool(load_result.get("ok", false)):
		var raw_data: Dictionary = load_result.get("data", {})
		_manager.save_data = _data_normalizer().normalize_save_data(raw_data)
		loaded_from = str(load_result.get("source", "primary"))
		rewrite_reason = _rewrite_reason(raw_data)
		if not rewrite_reason.is_empty():
			needs_write = true
		if loaded_from != "primary":
			recovered_from = loaded_from
			needs_write = true
	else:
		_manager.save_data = _data_normalizer().default_save_data()
		needs_write = true

	return {
		"loaded_from": loaded_from,
		"recovered_from": recovered_from,
		"needs_write": needs_write,
		"rewrite_reason": rewrite_reason
	}


func _prepare_runtime_after_load(load_context: Dictionary) -> void:
	if _profile_service().ensure_local_profile():
		load_context["needs_write"] = true
	if _resume_service().repair_resume_state():
		load_context["needs_write"] = true


func _rewrite_reason(raw_data: Dictionary) -> String:
	if raw_data.has("users"):
		return "legacy_migration"
	if raw_data.has("sessions"):
		return "schema_simplification"
	if raw_data.has("active_session_id") or raw_data.has("next_session_number"):
		return "schema_simplification"
	return ""


func _finalize_load_status(load_context: Dictionary) -> void:
	var needs_write: bool = bool(load_context.get("needs_write", false))

	var loaded_from: String = str(load_context.get("loaded_from", "default"))
	var recovered_from: String = str(load_context.get("recovered_from", ""))
	var rewrite_reason: String = str(load_context.get("rewrite_reason", ""))
	if needs_write:
		_finish_load_with_repair(loaded_from, recovered_from, rewrite_reason)
		return

	_manager.last_saved_snapshot = _storage_helper().serialize_save_data(_manager.save_data)
	_manager.has_unsaved_changes = false
	_write_coordinator().emit_save_status("ready", loaded_from)


func _finish_load_with_repair(
	loaded_from: String,
	recovered_from: String,
	rewrite_reason: String = ""
) -> void:
	_manager.runtime_save_status["last_loaded_from"] = loaded_from
	_manager.runtime_save_status["recovered_from"] = recovered_from
	var effective_reason: String = rewrite_reason
	if effective_reason.is_empty():
		effective_reason = "load_repair"
	if not _write_coordinator().write_save_data(true, effective_reason):
		if not recovered_from.is_empty() and FileAccess.file_exists(_manager.TEMP_SAVE_PATH):
			_manager.last_saved_snapshot = _storage_helper().serialize_save_data(_manager.save_data)
			_manager.has_unsaved_changes = false
			_write_coordinator().emit_save_status("recovered", loaded_from, recovered_from)
			return
		_write_coordinator().emit_save_status(
			"error",
			loaded_from,
			recovered_from,
			"No se pudo restaurar el save principal en disco."
		)
		return
	if recovered_from.is_empty():
		_write_coordinator().emit_save_status("ready", loaded_from)
		return
	_write_coordinator().emit_save_status("recovered", loaded_from, recovered_from)


func _data_normalizer():
	return _manager.data_normalizer()


func _profile_service():
	return _manager.profile_service()


func _resume_service():
	return _manager.resume_service()


func _write_coordinator():
	return _manager.write_coordinator()


func _storage_helper():
	return _manager.storage_helper()
