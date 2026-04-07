extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func project_active_session_to_runtime() -> void:
	var active_session: Dictionary = get_active_session_data()
	if active_session.is_empty():
		_manager.save_data["progress"] = _manager.save_data.get("progress", {}) if _manager.save_data.get("progress", {}) is Dictionary else {}
		_manager.save_data["history"] = _manager._normalize_history(_manager.save_data.get("history", []))
		_manager.save_data["resume_state"] = _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
		_manager.save_data["save_meta"] = _manager._normalize_save_meta(_manager.save_data.get("save_meta", {}))
		return
	_manager.save_data["progress"] = active_session.get("progress", {}).duplicate(true)
	_manager.save_data["history"] = _manager._normalize_history(active_session.get("history", []))
	_manager.save_data["resume_state"] = _manager._normalize_resume_state(active_session.get("resume_state", {}))
	_manager.save_data["save_meta"] = _manager._normalize_save_meta(active_session.get("save_meta", {}))


func get_active_session_data() -> Dictionary:
	return get_session_data(_manager.get_active_save_slot_id())


func get_session_data(session_id: String) -> Dictionary:
	var raw_sessions: Variant = _manager.save_data.get("sessions", {})
	if not raw_sessions is Dictionary:
		return {}
	var sessions: Dictionary = raw_sessions
	var clean_session_id: String = session_id.strip_edges()
	if clean_session_id.is_empty() or not sessions.has(clean_session_id) or not sessions[clean_session_id] is Dictionary:
		return {}
	return _manager._normalize_session_data(sessions[clean_session_id], clean_session_id)


func get_session_resume_state(session_id: String) -> Dictionary:
	var session: Dictionary = get_session_data(session_id)
	if session.is_empty():
		return _manager._default_resume_state()
	return resolve_resume_state(_manager._normalize_resume_state(session.get("resume_state", {})))


func has_active_session() -> bool:
	return not get_active_session_data().is_empty()


func activate_session(session_id: String) -> bool:
	var session: Dictionary = get_session_data(session_id)
	if session.is_empty():
		return false
	if str(_manager.save_data.get("active_session_id", "")) != str(session.get("id", "")):
		_manager.save_data["active_session_id"] = str(session.get("id", ""))
		_manager._mark_dirty()
	project_active_session_to_runtime()
	return true


func create_session(title: String = "", activate: bool = true) -> Dictionary:
	var raw_sessions: Variant = _manager.save_data.get("sessions", {})
	var sessions: Dictionary = {}
	if raw_sessions is Dictionary:
		sessions = raw_sessions

	var next_session_number: int = max(1, int(_manager.save_data.get("next_session_number", 1)))
	var session_id: String = "%s%04d" % [_manager.SESSION_ID_PREFIX, next_session_number]
	while sessions.has(session_id):
		next_session_number += 1
		session_id = "%s%04d" % [_manager.SESSION_ID_PREFIX, next_session_number]

	var clean_title: String = _manager._normalize_session_title_value(title)
	if clean_title.is_empty():
		clean_title = _manager._build_default_session_title(next_session_number)
	elif clean_title.length() > _manager.SESSION_TITLE_MAX_LENGTH:
		clean_title = clean_title.left(_manager.SESSION_TITLE_MAX_LENGTH)

	var session: Dictionary = _manager._default_session_data(session_id, clean_title)
	var progress: Variant = _manager.save_data.get("progress", {})
	if progress is Dictionary:
		session["progress"] = progress.duplicate(true)
	session["history"] = _manager._normalize_history(_manager.save_data.get("history", []))
	session["resume_state"] = _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
	session["save_meta"] = _manager._normalize_save_meta(_manager.save_data.get("save_meta", {}))
	session["updated_at"] = _manager._session_updated_at(session)

	sessions[session_id] = session
	_manager.save_data["sessions"] = sessions
	_manager.save_data["next_session_number"] = next_session_number + 1
	if activate:
		_manager.save_data["active_session_id"] = session_id
		project_active_session_to_runtime()
	_manager._mark_dirty()
	return session.duplicate(true)


func rename_active_session(title: String) -> void:
	var clean_title: String = _manager._normalize_session_title_value(title)
	if clean_title.is_empty() or not has_active_session():
		return
	if clean_title.length() > _manager.SESSION_TITLE_MAX_LENGTH:
		clean_title = clean_title.left(_manager.SESSION_TITLE_MAX_LENGTH)
	var active_session_id: String = _manager.get_active_save_slot_id()
	var raw_sessions: Variant = _manager.save_data.get("sessions", {})
	if not raw_sessions is Dictionary:
		return
	var sessions: Dictionary = raw_sessions
	if not sessions.has(active_session_id) or not sessions[active_session_id] is Dictionary:
		return
	var session: Dictionary = _manager._normalize_session_data(sessions[active_session_id], active_session_id)
	if str(session.get("title", "")) == clean_title:
		return
	session["title"] = clean_title
	sessions[active_session_id] = session
	_manager.save_data["sessions"] = sessions
	_manager._mark_dirty()


func reset_runtime_session_projection() -> void:
	_manager.save_data["progress"] = {}
	_manager.save_data["history"] = []
	_manager.save_data["resume_state"] = _manager._default_resume_state()
	_manager.save_data["save_meta"] = _manager._default_save_meta()
	_manager._mark_dirty()


func sync_active_session_to_storage(save_meta: Dictionary) -> void:
	var active_session_id: String = _manager.get_active_save_slot_id()
	if active_session_id.is_empty():
		return
	var raw_sessions: Variant = _manager.save_data.get("sessions", {})
	if not raw_sessions is Dictionary:
		return
	var sessions: Dictionary = raw_sessions
	if not sessions.has(active_session_id) or not sessions[active_session_id] is Dictionary:
		return

	var session: Dictionary = _manager._normalize_session_data(sessions[active_session_id], active_session_id)
	var progress: Variant = _manager.save_data.get("progress", {})
	if progress is Dictionary:
		session["progress"] = progress.duplicate(true)
	session["history"] = _manager._normalize_history(_manager.save_data.get("history", []))
	session["resume_state"] = _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
	session["save_meta"] = save_meta.duplicate(true)
	session["updated_at"] = _manager._session_updated_at(session)
	sessions[active_session_id] = session
	_manager.save_data["sessions"] = sessions


func ensure_active_session_for_write(reason: String) -> void:
	if has_active_session():
		return
	if reason == "profile_updated" or reason == "legacy_migration":
		return
	if reason == "load_repair" and not runtime_projection_has_session_content():
		return
	if reason != "load_repair" and not runtime_projection_has_session_content():
		return
	create_session("", true)


func build_session_summary(session: Dictionary) -> Dictionary:
	var progress_summary: Dictionary = _manager._summarize_progress_data(session.get("progress", {}))
	var session_id: String = str(session.get("id", ""))
	var resume_state: Dictionary = _manager._normalize_resume_state(session.get("resume_state", {}))
	return {
		"id": session_id,
		"title": str(session.get("title", _manager._build_default_session_title_from_id(session_id))),
		"created_at": str(session.get("created_at", "")),
		"updated_at": _manager._session_updated_at(session),
		"resume_hint": _manager._format_resume_hint_from_state(resume_state),
		"resume_context": str(resume_state.get("context", _manager.RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume_state.get("track_key", "")),
		"resume_level_number": int(resume_state.get("level_number", 1)),
		"progress_summary": progress_summary,
		"can_resume": session_can_resume(session),
		"is_active": session_id == _manager.get_active_save_slot_id()
	}


func sort_save_slot_summaries(left: Dictionary, right: Dictionary) -> bool:
	var left_updated_at := str(left.get("updated_at", ""))
	var right_updated_at := str(right.get("updated_at", ""))
	if left_updated_at == right_updated_at:
		return str(left.get("title", "")) < str(right.get("title", ""))
	return left_updated_at > right_updated_at


func session_can_resume(session: Dictionary) -> bool:
	if session.is_empty():
		return false
	var summary: Dictionary = _manager._summarize_progress_data(session.get("progress", {}))
	if int(summary.get("total", 0)) > 0:
		return true
	var resume_state: Dictionary = _manager._normalize_resume_state(session.get("resume_state", {}))
	if str(resume_state.get("context", _manager.RESUME_CONTEXT_HUB)) != _manager.RESUME_CONTEXT_HUB:
		return true
	var history: Variant = session.get("history", [])
	if history is Array:
		for entry in history:
			if not entry is Dictionary:
				continue
			var metadata = entry.get("metadata", {})
			if metadata is Dictionary and _manager.GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
				return true
	return false


func runtime_projection_has_session_content() -> bool:
	return session_can_resume({
		"progress": _manager.save_data.get("progress", {}),
		"resume_state": _manager.save_data.get("resume_state", {}),
		"history": _manager.save_data.get("history", [])
	})


func resolve_resume_state(normalized_resume_state: Dictionary) -> Dictionary:
	var context: String = str(normalized_resume_state.get("context", _manager.RESUME_CONTEXT_HUB))
	if context == _manager.RESUME_CONTEXT_LEVEL:
		return normalized_resume_state
	var derived_resume_state: Dictionary = derive_resume_state_from_history()
	if derived_resume_state.is_empty():
		return normalized_resume_state
	return derived_resume_state


func derive_resume_state_from_history() -> Dictionary:
	var history: Variant = _manager.save_data.get("history", [])
	if not history is Array:
		return {}
	for entry in history:
		if not entry is Dictionary:
			continue
		var metadata: Variant = entry.get("metadata", {})
		if not metadata is Dictionary:
			continue
		var entry_type: String = str(metadata.get("type", "")).strip_edges()
		if entry_type == "new_game":
			return {}
		if entry_type == "manual_save":
			var saved_resume_state: Dictionary = resume_state_from_history_metadata(metadata)
			if not saved_resume_state.is_empty():
				return saved_resume_state
		elif entry_type == "level_completed":
			var completed_resume_state: Dictionary = resume_state_after_completed_level(metadata)
			if not completed_resume_state.is_empty():
				return completed_resume_state
	return {}


func resume_state_from_history_metadata(metadata: Dictionary) -> Dictionary:
	var context: String = str(metadata.get("context", "")).strip_edges()
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	if context != _manager.RESUME_CONTEXT_LEVEL or not _manager._is_known_track(track_key):
		return {}
	return {
		"context": _manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": _manager._get_level_scene_path(track_key),
		"level_number": clampi(int(metadata.get("level", 1)), 1, Global.get_track_level_count(track_key))
	}


func resume_state_after_completed_level(metadata: Dictionary) -> Dictionary:
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	if not _manager._is_known_track(track_key):
		return {}
	var completed_level: int = clampi(int(metadata.get("level", 1)), 1, Global.get_track_level_count(track_key))
	if not is_saved_level_completed(track_key, completed_level):
		return {}
	if completed_level >= Global.get_track_level_count(track_key):
		return _manager._default_resume_state()
	return {
		"context": _manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": _manager._get_level_scene_path(track_key),
		"level_number": completed_level + 1
	}


func is_saved_level_completed(track_key: String, level_number: int) -> bool:
	var progress: Variant = _manager.save_data.get("progress", {})
	if not progress is Dictionary:
		return false
	var track_progress: Variant = progress.get(track_key, [])
	if not track_progress is Array:
		return false
	var level_index: int = level_number - 1
	if level_index < 0 or level_index >= track_progress.size():
		return false
	return bool(track_progress[level_index])