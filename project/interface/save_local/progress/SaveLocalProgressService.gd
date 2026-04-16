extends RefCounted

var _save_manager


func _init(save_manager):
	_save_manager = save_manager


func sync_runtime_progress_to_current_save() -> void:
	var current_profile: Dictionary = _save_manager.get_current_user_profile()
	_store_current_runtime_progress(current_profile)
	_get_write_coordinator().mark_dirty()

func persist_runtime_progress_to_current_save() -> void:
	sync_runtime_progress_to_current_save()
	if _get_write_coordinator().write_save_data(false, "progress_sync"):
		_save_manager.progress_saved.emit(_save_manager.get_current_user_profile())


func sync_runtime_progress_from_current_save() -> void:
	Global.import_progress(_save_manager.save_data.get("progress", {}))


func sync_runtime_progress_from_current_save_and_emit_signal() -> void:
	sync_runtime_progress_from_current_save()
	_save_manager.progress_loaded.emit(_save_manager.get_current_user_profile())


func reload_current_save_and_get_resume_state() -> Dictionary:
	_save_manager.load_data()
	sync_runtime_progress_from_current_save()
	return _apply_resume_level_to_global_state(_save_manager.get_resume_state())


func reload_current_save_and_get_resume_state_and_emit_signal() -> Dictionary:
	_save_manager.load_data()
	sync_runtime_progress_from_current_save_and_emit_signal()
	return _apply_resume_level_to_global_state(_save_manager.get_resume_state())


func reset_all_progress() -> Dictionary:
	var current_profile: Dictionary = _save_manager.get_current_user_profile()
	_reset_current_save_data(current_profile)

	if not _get_write_coordinator().write_save_data(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}

	_save_manager.progress_loaded.emit(current_profile)
	_save_manager.progress_saved.emit(current_profile)
	return {
		"ok": true,
		"message": "Se reinicio el progreso local.",
		"profile": current_profile
	}


func start_new_game(_save_title: String = "") -> bool:
	_save_manager.load_data()
	var current_profile: Dictionary = _save_manager.get_current_user_profile()
	_reset_current_save_data(current_profile)
	_get_resume_service().append_history("Nueva partida iniciada", {"type": "new_game"})
	if not _get_write_coordinator().write_save_data(false, "new_game"):
		return false
	_emit_progress_refresh_signals()
	return true


func _reset_current_save_data(profile: Dictionary) -> void:
	Global.reset_progress()
	_store_current_runtime_progress(profile)
	_save_manager.save_data["history"] = []
	_save_manager.save_data["resume_state"] = _get_save_data_normalizer().default_resume_state()
	_save_manager.save_data["save_meta"] = _get_save_data_normalizer().default_save_meta()
	_get_write_coordinator().mark_dirty()


func _store_current_runtime_progress(profile: Dictionary) -> void:
	_save_manager.save_data["profile"] = profile
	_save_manager.save_data["progress"] = Global.export_progress()


func _apply_resume_level_to_global_state(resume_state: Dictionary) -> Dictionary:
	var resume_track_key: String = str(resume_state.get("track_key", ""))
	Global.current_level = clampi(
		int(resume_state.get("level_number", Global.current_level)),
		1,
		Global.get_track_level_count(resume_track_key)
	)
	return resume_state


func _emit_progress_refresh_signals() -> void:
	var current_profile: Dictionary = _save_manager.get_current_user_profile()
	_save_manager.progress_loaded.emit(current_profile)
	_save_manager.progress_saved.emit(current_profile)


func _get_resume_service():
	return _save_manager.get_resume_service()


func _get_write_coordinator():
	return _save_manager.get_write_coordinator()


func _get_save_data_normalizer():
	return _save_manager.get_save_data_normalizer()
