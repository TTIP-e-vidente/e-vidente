extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	var current_resume_state := get_resume_state()
	if not allow_level_downgrade and str(current_resume_state.get("context", _manager.RESUME_CONTEXT_HUB)) == _manager.RESUME_CONTEXT_LEVEL:
		return
	set_resume_state({
		"context": _manager.RESUME_CONTEXT_BOOK,
		"track_key": track_key,
		"scene_path": _manager._get_book_scene_path(track_key),
		"level_number": clampi(Global.current_level, 1, Global.get_track_level_count(track_key))
	})


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	var resolved_level: int = Global.current_level if level_number < 1 else level_number
	set_resume_state({
		"context": _manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": _manager._get_level_scene_path(track_key),
		"level_number": clampi(resolved_level, 1, Global.get_track_level_count(track_key))
	})


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	if level_number < Global.get_track_level_count(track_key):
		set_resume_to_level(track_key, level_number + 1)
		return
	set_resume_state(_manager._default_resume_state())


func get_resume_state() -> Dictionary:
	var raw_resume_state: Variant = _manager.save_data.get("resume_state", {})
	if not raw_resume_state is Dictionary:
		return _manager._resolve_resume_state(_manager._default_resume_state())
	return _manager._resolve_resume_state(_manager._normalize_resume_state(raw_resume_state))


func get_resume_hint(session_id: String = "") -> String:
	var resume_state := get_resume_state() if session_id.strip_edges().is_empty() else _manager._get_session_resume_state(session_id)
	return _manager._format_resume_hint_from_state(resume_state)


func can_resume_game(session_id: String = "") -> bool:
	var requested_session_id := session_id.strip_edges()
	if not requested_session_id.is_empty():
		return _manager._session_can_resume(_manager._get_session_data(requested_session_id))
	return not _manager.list_save_slots().is_empty()


func record_level_completed(track_key: String, level_number: int) -> void:
	Global.clear_partial_level_state(track_key, level_number)
	set_resume_after_level_completed(track_key, level_number)
	_manager.save_current_user_progress(false)
	append_history("Completaste %s - capitulo %d" % [Global.get_track_label(track_key), level_number], {
		"type": "level_completed",
		"track": track_key,
		"level": level_number,
		"session_id": _manager.get_active_save_slot_id()
	})
	if _manager._write_save_data(false, "level_completed"):
		_manager.progress_saved.emit(_manager.get_current_user_profile())


func record_manual_save() -> void:
	_manager.save_current_user_progress(false)
	var resume_state := get_resume_state()
	append_history("Guardado manual", {
		"type": "manual_save",
		"context": str(resume_state.get("context", _manager.RESUME_CONTEXT_HUB)),
		"track": str(resume_state.get("track_key", "")),
		"level": int(resume_state.get("level_number", Global.current_level)),
		"session_id": _manager.get_active_save_slot_id()
	})
	if _manager._write_save_data(false, "manual_save"):
		_manager.progress_saved.emit(_manager.get_current_user_profile())


func append_history(message: String, metadata: Dictionary = {}) -> void:
	var raw_history: Variant = _manager.save_data.get("history", [])
	var history: Array = raw_history if raw_history is Array else []
	history.push_front({
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	})
	if history.size() > _manager.HISTORY_LIMIT:
		history = history.slice(0, _manager.HISTORY_LIMIT)
	_manager.save_data["history"] = history
	_manager._mark_dirty()


func repair_resume_state() -> bool:
	var stored_resume_state := _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
	var resolved_resume_state := _manager._resolve_resume_state(stored_resume_state)
	if stored_resume_state == resolved_resume_state:
		return false
	_manager.save_data["resume_state"] = resolved_resume_state
	_manager._mark_dirty()
	return true


func set_resume_state(raw_resume_state: Dictionary) -> void:
	var normalized_resume_state := _manager._normalize_resume_state(raw_resume_state)
	var current_resume_state := _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
	_manager.save_data["resume_state"] = normalized_resume_state
	if current_resume_state == normalized_resume_state:
		return
	_manager._mark_dirty()