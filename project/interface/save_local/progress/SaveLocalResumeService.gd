extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	if _should_keep_current_level_resume(allow_level_downgrade):
		return
	set_resume_state(_build_book_resume_state(track_key))


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	var resolved_level: int = Global.current_level if level_number < 1 else level_number
	set_resume_state(_build_level_resume_state(track_key, resolved_level))


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	if level_number < Global.get_track_level_count(track_key):
		set_resume_to_level(track_key, level_number + 1)
		return
	set_resume_state(_data_normalizer().default_resume_state())


func get_resume_state() -> Dictionary:
	var raw_resume_state: Variant = _manager.save_data.get("resume_state", {})
	if not raw_resume_state is Dictionary:
		return _resolve_resume_state(_data_normalizer().default_resume_state())
	return _resolve_resume_state(_data_normalizer().normalize_resume_state(raw_resume_state))


func get_current_resume_hint() -> String:
	var resume_state: Dictionary = get_resume_state()
	return _progress_state_helper().format_resume_hint_from_state(
		resume_state,
		_manager.RESUME_CONTEXT_HUB,
		_manager.RESUME_CONTEXT_BOOK,
		_manager.RESUME_CONTEXT_LEVEL,
		Global.get_track_labels()
	)


func can_resume_current_save() -> bool:
	return _save_can_resume()


func record_level_completed(track_key: String, level_number: int) -> void:
	Global.clear_partial_level_state(track_key, level_number)
	set_resume_after_level_completed(track_key, level_number)
	_manager.sync_runtime_progress_to_current_save()
	append_history(
		"Completaste %s - capitulo %d" % [Global.get_track_label(track_key), level_number],
		{
			"type": "level_completed",
			"track": track_key,
			"level": level_number
		}
	)
	_persist_progress_event("level_completed")


func record_manual_save() -> void:
	_manager.sync_runtime_progress_to_current_save()
	var resume_state: Dictionary = get_resume_state()
	append_history("Guardado manual", _build_manual_save_metadata(resume_state))
	_persist_progress_event("manual_save")


func append_history(message: String, metadata: Dictionary = {}) -> void:
	var raw_history: Variant = _manager.save_data.get("history", [])
	var history: Array = raw_history if raw_history is Array else []
	history.push_front(_build_history_entry(message, metadata))
	if history.size() > _manager.HISTORY_LIMIT:
		history = history.slice(0, _manager.HISTORY_LIMIT)
	_manager.save_data["history"] = history
	_write_coordinator().mark_dirty()


func repair_resume_state() -> bool:
	var stored_resume_state: Dictionary = _data_normalizer().normalize_resume_state(
		_manager.save_data.get("resume_state", {})
	)
	var resolved_resume_state: Dictionary = _resolve_resume_state(stored_resume_state)
	if stored_resume_state == resolved_resume_state:
		return false
	_manager.save_data["resume_state"] = resolved_resume_state
	_write_coordinator().mark_dirty()
	return true


func set_resume_state(raw_resume_state: Dictionary) -> void:
	var normalized_resume_state: Dictionary = (
		_data_normalizer().normalize_resume_state(raw_resume_state)
	)
	var current_resume_state: Dictionary = _data_normalizer().normalize_resume_state(
		_manager.save_data.get("resume_state", {})
	)
	_manager.save_data["resume_state"] = normalized_resume_state
	if current_resume_state == normalized_resume_state:
		return
	_write_coordinator().mark_dirty()


func _should_keep_current_level_resume(allow_level_downgrade: bool) -> bool:
	if allow_level_downgrade:
		return false
	var current_resume_state: Dictionary = get_resume_state()
	return (
		str(current_resume_state.get("context", _manager.RESUME_CONTEXT_HUB))
		== _manager.RESUME_CONTEXT_LEVEL
	)


func _build_book_resume_state(track_key: String) -> Dictionary:
	return {
		"context": _manager.RESUME_CONTEXT_BOOK,
		"track_key": track_key,
		"scene_path": Global.get_book_scene_path(track_key),
		"level_number": clampi(Global.current_level, 1, Global.get_track_level_count(track_key))
	}


func _build_level_resume_state(track_key: String, level_number: int) -> Dictionary:
	return {
		"context": _manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": Global.get_level_scene_path(track_key),
		"level_number": clampi(level_number, 1, Global.get_track_level_count(track_key))
	}


func _build_manual_save_metadata(resume_state: Dictionary) -> Dictionary:
	return {
		"type": "manual_save",
		"context": str(resume_state.get("context", _manager.RESUME_CONTEXT_HUB)),
		"track": str(resume_state.get("track_key", "")),
		"level": int(resume_state.get("level_number", Global.current_level))
	}


func _resolve_resume_state(normalized_resume_state: Dictionary) -> Dictionary:
	var context: String = str(normalized_resume_state.get("context", _manager.RESUME_CONTEXT_HUB))
	if context == _manager.RESUME_CONTEXT_LEVEL:
		return normalized_resume_state
	var history_resume_state: Dictionary = _derive_resume_state_from_history()
	if history_resume_state.is_empty():
		return normalized_resume_state
	return history_resume_state


func _derive_resume_state_from_history() -> Dictionary:
	var history: Variant = _manager.save_data.get("history", [])
	if not history is Array:
		return {}

	for entry in history:
		var metadata: Dictionary = _history_metadata(entry)
		if metadata.is_empty():
			continue
		var entry_type: String = str(metadata.get("type", "")).strip_edges()
		if entry_type == "new_game":
			return {}
		if entry_type == "manual_save":
			var manual_resume_state: Dictionary = _resume_state_from_history_metadata(metadata)
			if not manual_resume_state.is_empty():
				return manual_resume_state
			continue
		if entry_type == "level_completed":
			var completed_resume_state: Dictionary = _resume_state_after_completed_level(metadata)
			if not completed_resume_state.is_empty():
				return completed_resume_state
	return {}


func _resume_state_from_history_metadata(metadata: Dictionary) -> Dictionary:
	var context: String = str(metadata.get("context", "")).strip_edges()
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	if context != _manager.RESUME_CONTEXT_LEVEL:
		return {}
	if not Global.has_track(track_key):
		return {}
	return {
		"context": _manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": Global.get_level_scene_path(track_key),
		"level_number": clampi(
			int(metadata.get("level", 1)),
			1,
			Global.get_track_level_count(track_key)
		)
	}


func _resume_state_after_completed_level(metadata: Dictionary) -> Dictionary:
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	if not Global.has_track(track_key):
		return {}
	var completed_level: int = clampi(
		int(metadata.get("level", 1)),
		1,
		Global.get_track_level_count(track_key)
	)
	if not _is_saved_level_completed(track_key, completed_level):
		return {}
	if completed_level >= Global.get_track_level_count(track_key):
		return _data_normalizer().default_resume_state()
	return {
		"context": _manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": Global.get_level_scene_path(track_key),
		"level_number": completed_level + 1
	}


func _is_saved_level_completed(track_key: String, level_number: int) -> bool:
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


func _save_can_resume() -> bool:
	var progress_summary: Dictionary = _manager.summarize_progress_data(
		_manager.save_data.get("progress", {})
	)
	if int(progress_summary.get("total", 0)) > 0:
		return true
	var resume_state: Dictionary = _data_normalizer().normalize_resume_state(
		_manager.save_data.get("resume_state", {})
	)
	if str(resume_state.get("context", _manager.RESUME_CONTEXT_HUB)) != _manager.RESUME_CONTEXT_HUB:
		return true
	return _history_contains_gameplay_progress(_manager.save_data.get("history", []))


func _history_contains_gameplay_progress(raw_history: Variant) -> bool:
	if not raw_history is Array:
		return false
	for entry in raw_history:
		var metadata: Dictionary = _history_metadata(entry)
		if metadata.is_empty():
			continue
		if _manager.GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
			return true
	return false


func _history_metadata(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var metadata: Variant = entry.get("metadata", {})
	return metadata if metadata is Dictionary else {}


func _persist_progress_event(reason: String) -> void:
	if _write_coordinator().write_save_data(false, reason):
		_manager.progress_saved.emit(_manager.get_current_user_profile())


func _build_history_entry(message: String, metadata: Dictionary) -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	}


func _write_coordinator():
	return _manager.get_write_coordinator()


func _data_normalizer():
	return _manager.get_save_data_normalizer()


func _progress_state_helper():
	return _manager.get_progress_state_helper()
