extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func save_current_user_progress(write_to_disk: bool = true) -> void:
	var profile: Dictionary = _manager.get_current_user_profile()
	_manager.save_data["profile"] = profile
	_manager.save_data["progress"] = Global.export_progress()
	_manager._mark_dirty()

	if write_to_disk:
		if _manager._write_save_data(false, "progress_sync"):
			_manager.progress_saved.emit(_manager.get_current_user_profile())


func load_current_user_progress(should_emit_progress_signal: bool = true) -> void:
	Global.import_progress(_manager.save_data.get("progress", {}))
	if should_emit_progress_signal:
		_manager.progress_loaded.emit(_manager.get_current_user_profile())


func load_progress_and_get_resume_state(should_emit_progress_signal: bool = false) -> Dictionary:
	_manager.load_data()
	if not _manager._has_active_session():
		var recent_session_id: String = _manager.get_recent_save_slot_id()
		if not recent_session_id.is_empty():
			_manager._activate_session(recent_session_id)
	load_current_user_progress(should_emit_progress_signal)
	var resume_state: Dictionary = _manager.get_resume_state()
	var track_key: String = str(resume_state.get("track_key", ""))
	Global.current_level = clampi(int(resume_state.get("level_number", Global.current_level)), 1, Global.get_track_level_count(track_key))
	return resume_state


func load_slot_and_get_resume_state(session_id: String, should_emit_progress_signal: bool = false) -> Dictionary:
	_manager.load_data()
	if not _manager._activate_session(session_id):
		return _manager._default_resume_state()
	load_current_user_progress(should_emit_progress_signal)
	var resume_state: Dictionary = _manager.get_resume_state()
	var track_key: String = str(resume_state.get("track_key", ""))
	Global.current_level = clampi(int(resume_state.get("level_number", Global.current_level)), 1, Global.get_track_level_count(track_key))
	return resume_state


func reset_all_progress() -> Dictionary:
	var profile: Dictionary = _manager.get_current_user_profile()
	_manager.save_data["sessions"] = {}
	_manager.save_data["active_session_id"] = ""
	_manager.save_data["next_session_number"] = 1
	_manager.save_data["history"] = []
	_manager.save_data["resume_state"] = _manager._default_resume_state()
	Global.reset_progress()
	_manager.save_data["progress"] = Global.export_progress()
	_manager._mark_dirty()

	if not _manager._write_save_data(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}

	_manager.progress_loaded.emit(profile)
	_manager.progress_saved.emit(profile)
	return {"ok": true, "message": "Se reinicio el progreso local.", "profile": profile}


func start_new_game(title: String = "") -> bool:
	_manager.load_data()
	var title_validation: Dictionary = _manager.validate_session_title(title)
	if not bool(title_validation.get("ok", false)):
		return false
	var normalized_title: String = str(title_validation.get("title", ""))
	var should_reuse_active_session: bool = _manager._has_active_session() and not _manager._session_can_resume(_manager._get_active_session_data())
	if _manager._has_active_session() and not should_reuse_active_session:
		save_current_user_progress()

	_manager._reset_runtime_session_projection()
	if should_reuse_active_session:
		_manager._rename_active_session(normalized_title)
	else:
		_manager._create_session(normalized_title, true)

	Global.reset_progress()
	save_current_user_progress(false)
	_manager._append_history("Nueva partida iniciada", {
		"type": "new_game",
		"session_id": _manager.get_active_save_slot_id()
	})
	if not _manager._write_save_data(false, "new_game"):
		return false
	var profile: Dictionary = _manager.get_current_user_profile()
	_manager.progress_loaded.emit(profile)
	_manager.progress_saved.emit(profile)
	return true