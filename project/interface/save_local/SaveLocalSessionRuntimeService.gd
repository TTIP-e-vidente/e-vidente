extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func project_active_session_to_runtime() -> void:
	var active_session: Dictionary = get_active_session_data()
	if active_session.is_empty():
		_project_default_runtime_state()
		return
	_project_runtime_state_from_session(active_session)


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
	var sessions: Dictionary = raw_sessions if raw_sessions is Dictionary else {}

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
	if reason == "load_repair" and not _runtime_projection_has_session_content():
		return
	if reason != "load_repair" and not _runtime_projection_has_session_content():
		return
	create_session("", true)


func _project_default_runtime_state() -> void:
	var raw_progress: Variant = _manager.save_data.get("progress", {})
	_manager.save_data["progress"] = raw_progress if raw_progress is Dictionary else {}
	_manager.save_data["history"] = _manager._normalize_history(_manager.save_data.get("history", []))
	_manager.save_data["resume_state"] = _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
	_manager.save_data["save_meta"] = _manager._normalize_save_meta(_manager.save_data.get("save_meta", {}))


func _project_runtime_state_from_session(session: Dictionary) -> void:
	var raw_progress: Variant = session.get("progress", {})
	_manager.save_data["progress"] = raw_progress.duplicate(true) if raw_progress is Dictionary else {}
	_manager.save_data["history"] = _manager._normalize_history(session.get("history", []))
	_manager.save_data["resume_state"] = _manager._normalize_resume_state(session.get("resume_state", {}))
	_manager.save_data["save_meta"] = _manager._normalize_save_meta(session.get("save_meta", {}))


func _runtime_projection_has_session_content() -> bool:
	var summary: Dictionary = _manager._summarize_progress_data(_manager.save_data.get("progress", {}))
	if int(summary.get("total", 0)) > 0:
		return true
	var resume_state: Dictionary = _manager._normalize_resume_state(_manager.save_data.get("resume_state", {}))
	if str(resume_state.get("context", _manager.RESUME_CONTEXT_HUB)) != _manager.RESUME_CONTEXT_HUB:
		return true
	var history: Variant = _manager.save_data.get("history", [])
	if history is Array:
		for entry in history:
			if not entry is Dictionary:
				continue
			var metadata: Variant = entry.get("metadata", {})
			if metadata is Dictionary and _manager.GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
				return true
	return false