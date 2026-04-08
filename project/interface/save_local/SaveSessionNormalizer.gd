extends RefCounted

var _session_helper
var _config: Dictionary = {}
var _normalize_save_meta: Callable
var _normalize_history: Callable

func _init(session_helper, config: Dictionary, normalize_save_meta: Callable, normalize_history: Callable):
	_session_helper = session_helper
	_config = config.duplicate(true)
	_normalize_save_meta = normalize_save_meta
	_normalize_history = normalize_history

func default_resume_state() -> Dictionary:
	return _session_helper.default_resume_state(str(_config.get("resume_context_hub", "hub")), str(_config.get("archivero_scene", "")))

func normalize_resume_state(raw_resume_state: Dictionary) -> Dictionary:
	return _session_helper.normalize_resume_state(
		raw_resume_state,
		_config.get("track_book_scene_paths", {}),
		_config.get("track_level_scene_paths", {}),
		_config.get("track_level_counts", {}),
		str(_config.get("archivero_scene", "")),
		str(_config.get("resume_context_hub", "hub")),
		str(_config.get("resume_context_book", "book")),
		str(_config.get("resume_context_level", "level")),
		int(_config.get("levels_per_book", 1))
	)

func default_session_data(session_id: String = "", title: String = "", created_at: String = "") -> Dictionary:
	var timestamp: String = created_at if not created_at.is_empty() else Time.get_datetime_string_from_system(false, true)
	return {"id": session_id, "title": title, "created_at": timestamp, "updated_at": timestamp, "progress": {}, "resume_state": default_resume_state(), "history": [], "save_meta": _session_helper.default_save_meta()}

func normalize_session_data(raw_session: Dictionary, session_id: String = "") -> Dictionary:
	var normalized_session_id: String = session_id if not session_id.is_empty() else str(raw_session.get("id", "")).strip_edges()
	var normalized: Dictionary = default_session_data(normalized_session_id, _normalize_session_title(str(raw_session.get("title", ""))), str(raw_session.get("created_at", "")))
	if normalized["title"] == "":
		normalized["title"] = _build_default_session_title_from_id(normalized_session_id)
	normalized["updated_at"] = str(raw_session.get("updated_at", normalized.get("created_at", "")))
	var raw_progress: Variant = raw_session.get("progress", {})
	if raw_progress is Dictionary:
		normalized["progress"] = raw_progress.duplicate(true)
	var raw_resume_state: Variant = raw_session.get("resume_state", {})
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = normalize_resume_state(raw_resume_state)
	normalized["history"] = _normalize_history.call(raw_session.get("history", []))
	var raw_save_meta: Variant = raw_session.get("save_meta", {})
	if raw_save_meta is Dictionary:
		normalized["save_meta"] = _normalize_save_meta.call(raw_save_meta)
	if normalized["updated_at"] == "":
		normalized["updated_at"] = _session_helper.session_updated_at(normalized)
	return normalized

func normalize_sessions(raw_sessions: Variant) -> Dictionary:
	var normalized_sessions: Dictionary = {}
	if raw_sessions is Dictionary:
		for raw_session_id in raw_sessions.keys():
			var session_id: String = str(raw_session_id)
			if raw_sessions[session_id] is Dictionary:
				normalized_sessions[session_id] = normalize_session_data(raw_sessions[session_id], session_id)
	return normalized_sessions

func migrate_single_session_data(raw_data: Dictionary) -> Dictionary:
	var candidate_session := {
		"id": "%s0001" % str(_config.get("session_id_prefix", "session_")),
		"title": _session_helper.build_default_session_title(str(_config.get("session_title_prefix", "Partida")), 1),
		"created_at": str(raw_data.get("profile", {}).get("created_at", "")),
		"updated_at": str(raw_data.get("save_meta", {}).get("last_saved_at", "")),
		"progress": raw_data.get("progress", {}),
		"resume_state": raw_data.get("resume_state", {}),
		"history": raw_data.get("history", []),
		"save_meta": raw_data.get("save_meta", {})
	}
	if not _session_can_resume(normalize_session_data(candidate_session, str(candidate_session.get("id", "")))):
		return {}
	return candidate_session

func sanitize_active_session_id(active_session_id: String, sessions: Dictionary) -> String:
	var clean_active_session_id: String = active_session_id.strip_edges()
	if not clean_active_session_id.is_empty() and sessions.has(clean_active_session_id) and sessions[clean_active_session_id] is Dictionary:
		return clean_active_session_id
	return find_most_recent_session_id(sessions)

func find_most_recent_session_id(sessions: Dictionary) -> String:
	var selected_session_id: String = ""
	var selected_updated_at: String = ""
	for raw_session_id in sessions.keys():
		var session_id: String = str(raw_session_id)
		if not sessions[session_id] is Dictionary:
			continue
		var updated_at: String = _session_helper.session_updated_at(normalize_session_data(sessions[session_id], session_id))
		if selected_session_id.is_empty() or updated_at > selected_updated_at:
			selected_session_id = session_id
			selected_updated_at = updated_at
	return selected_session_id

func _normalize_session_title(title: String) -> String:
	var clean_title: String = _session_helper.normalize_session_title_value(title)
	var max_length: int = int(_config.get("session_title_max_length", 40))
	return clean_title.left(max_length) if clean_title.length() > max_length else clean_title

func _build_default_session_title_from_id(session_id: String) -> String:
	return _session_helper.build_default_session_title_from_id(str(_config.get("session_title_prefix", "Partida")), str(_config.get("session_id_prefix", "session_")), session_id)

func _session_can_resume(session: Dictionary) -> bool:
	if session.is_empty():
		return false
	var summary: Dictionary = _session_helper.summarize_progress_data(session.get("progress", {}), _config.get("track_keys", []), _config.get("track_level_counts", {}))
	if int(summary.get("total", 0)) > 0:
		return true
	var resume_state: Dictionary = normalize_resume_state(session.get("resume_state", {}))
	if str(resume_state.get("context", str(_config.get("resume_context_hub", "hub")))) != str(_config.get("resume_context_hub", "hub")):
		return true
	var history: Variant = session.get("history", [])
	if history is Array:
		for entry in history:
			if not entry is Dictionary:
				continue
			var metadata = entry.get("metadata", {})
			if metadata is Dictionary and _config.get("gameplay_history_types", []).has(str(metadata.get("type", ""))):
				return true
	return false