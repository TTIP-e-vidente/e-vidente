extends RefCounted

var _manager


func _init(manager):
	_manager = manager


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
	var left_updated_at: String = str(left.get("updated_at", ""))
	var right_updated_at: String = str(right.get("updated_at", ""))
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
			var metadata: Variant = entry.get("metadata", {})
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