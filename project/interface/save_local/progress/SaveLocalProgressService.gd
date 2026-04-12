extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func save_current_user_progress(write_to_disk: bool = true) -> void:
	var profile: Dictionary = _manager.get_current_user_profile()
	_store_runtime_progress_snapshot(profile)
	_write_coordinator().mark_dirty()

	if write_to_disk and _write_coordinator().write_save_data(false, "progress_sync"):
		_manager.progress_saved.emit(_manager.get_current_user_profile())


func load_current_user_progress(should_emit_progress_signal: bool = true) -> void:
	Global.import_progress(_manager.save_data.get("progress", {}))
	if should_emit_progress_signal:
		_manager.progress_loaded.emit(_manager.get_current_user_profile())


func load_current_save_and_get_resume_state(
	should_emit_progress_signal: bool = false
) -> Dictionary:
	_manager.load_data()
	load_current_user_progress(should_emit_progress_signal)
	return _sync_global_level_with_resume_state(_manager.get_resume_state())


func reset_all_progress() -> Dictionary:
	var profile: Dictionary = _manager.get_current_user_profile()
	_reset_current_save_state(profile)

	if not _write_coordinator().write_save_data(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}

	_manager.progress_loaded.emit(profile)
	_manager.progress_saved.emit(profile)
	return {"ok": true, "message": "Se reinicio el progreso local.", "profile": profile}


func start_new_game(_title: String = "") -> bool:
	_manager.load_data()
	var profile: Dictionary = _manager.get_current_user_profile()
	_reset_current_save_state(profile)
	_resume_service().append_history("Nueva partida iniciada", {"type": "new_game"})
	if not _write_coordinator().write_save_data(false, "new_game"):
		return false
	_emit_progress_refresh_signals()
	return true


func _reset_current_save_state(profile: Dictionary) -> void:
	Global.reset_progress()
	_store_runtime_progress_snapshot(profile)
	_manager.save_data["history"] = []
	_manager.save_data["resume_state"] = _data_normalizer().default_resume_state()
	_manager.save_data["save_meta"] = _data_normalizer().default_save_meta()
	_write_coordinator().mark_dirty()


func _store_runtime_progress_snapshot(profile: Dictionary) -> void:
	_manager.save_data["profile"] = profile
	_manager.save_data["progress"] = Global.export_progress()


func _sync_global_level_with_resume_state(resume_state: Dictionary) -> Dictionary:
	var track_key: String = str(resume_state.get("track_key", ""))
	Global.current_level = clampi(
		int(resume_state.get("level_number", Global.current_level)),
		1,
		Global.get_track_level_count(track_key)
	)
	return resume_state


func _emit_progress_refresh_signals() -> void:
	var profile: Dictionary = _manager.get_current_user_profile()
	_manager.progress_loaded.emit(profile)
	_manager.progress_saved.emit(profile)


func _resume_service():
	return _manager.resume_service()


func _write_coordinator():
	return _manager.write_coordinator()


func _data_normalizer():
	return _manager.data_normalizer()
