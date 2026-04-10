extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func load_data() -> void:
	_manager.save_data = _manager._default_save_data()
	var load_result: Dictionary = _manager._load_available_save_data()
	var needs_write: bool = false
	var loaded_from: String = "default"
	var recovered_from: String = ""

	if bool(load_result.get("ok", false)):
		_manager.save_data = _manager._normalize_save_data(load_result.get("data", {}))
		loaded_from = str(load_result.get("source", "primary"))
		if loaded_from != "primary":
			recovered_from = loaded_from
			needs_write = true
	else:
		_manager.save_data = _manager._default_save_data()
		needs_write = true

	if _manager._ensure_local_profile():
		needs_write = true
	_manager._project_active_session_to_runtime()
	if _manager._repair_resume_state():
		needs_write = true

	if needs_write:
		if _manager._write_save_data(true, "load_repair"):
			if recovered_from.is_empty():
				_manager._emit_save_status("ready", loaded_from)
			else:
				_manager._emit_save_status("recovered", "primary", recovered_from)
		else:
			_manager._emit_save_status("error", loaded_from, recovered_from, "No se pudo restaurar el save principal en disco.")
	else:
		_manager.last_saved_snapshot = _manager._serialize_save_data()
		_manager.has_unsaved_changes = false
		_manager._emit_save_status("ready", loaded_from)

	Global.import_progress(_manager.save_data.get("progress", {}))