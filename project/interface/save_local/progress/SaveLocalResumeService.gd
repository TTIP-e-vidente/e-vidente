extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

var _save_manager


func _init(save_manager):
	_save_manager = save_manager


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	if _should_preserve_current_level_resume(allow_level_downgrade):
		return
	set_resume_state(_build_resume_state_for_book(track_key))


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	var level_number_to_resume: int = Global.current_level if level_number < 1 else level_number
	set_resume_state(_build_resume_state_for_level(track_key, level_number_to_resume))


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	if level_number < Global.get_track_level_count(track_key):
		set_resume_to_level(track_key, level_number + 1)
		return
	set_resume_state(_get_save_data_normalizer().default_resume_state())


func get_resume_state() -> Dictionary:
	var save_data_normalizer = _get_save_data_normalizer()
	var stored_resume_state: Variant = _save_manager.save_data.get("resume_state", {})
	if not stored_resume_state is Dictionary:
		return _resolve_resume_state_with_history_fallback(
			save_data_normalizer.default_resume_state()
		)
	return _resolve_resume_state_with_history_fallback(
		save_data_normalizer.normalize_resume_state(stored_resume_state)
	)


func get_current_resume_hint() -> String:
	var resume_state: Dictionary = get_resume_state()
	var progress_state_helper = _save_manager.get_progress_state_helper()
	return progress_state_helper.format_resume_hint_from_state(
		resume_state,
		_save_manager.RESUME_CONTEXT_HUB,
		_save_manager.RESUME_CONTEXT_BOOK,
		_save_manager.RESUME_CONTEXT_LEVEL,
		_build_track_label_by_key()
	)


func can_resume_current_save() -> bool:
	var saved_progress_summary: Dictionary = _save_manager.summarize_progress_data(
		_save_manager.save_data.get("progress", {})
	)
	if int(saved_progress_summary.get("total", 0)) > 0:
		return true

	var save_data_normalizer = _get_save_data_normalizer()
	var stored_resume_state: Dictionary = save_data_normalizer.normalize_resume_state(
		_save_manager.save_data.get("resume_state", {})
	)
	if (
		str(stored_resume_state.get("context", _save_manager.RESUME_CONTEXT_HUB))
		!= _save_manager.RESUME_CONTEXT_HUB
	):
		return true

	return _history_has_gameplay_progress(_save_manager.save_data.get("history", []))


func record_level_completed(track_key: String, level_number: int) -> Dictionary:
	var previous_streak_state: Dictionary = Global.get_streak_state()
	_clear_partial_progress_and_advance_resume(track_key, level_number)
	var updated_streak_state: Dictionary = Global.record_streak_activity(
		"level_completed",
		{
			"track_key": track_key,
			"level_number": level_number
		}
	)
	var streak_feedback: Dictionary = {"should_show": false}
	var today_day_key: String = Time.get_date_string_from_system(false)
	if str(previous_streak_state.get("last_activity_day", "")).strip_edges() != today_day_key:
		if str(updated_streak_state.get("last_activity_day", "")).strip_edges() == today_day_key:
			var current_count: int = int(updated_streak_state.get("current_count", 0))
			if current_count <= 1:
				streak_feedback = {
					"should_show": true,
					"feedback_key": "activated",
					"title": "Racha activada",
					"message": "Hoy empezaste una racha de 1 dia.",
					"current_count": 1,
					"best_count": int(updated_streak_state.get("best_count", 0))
				}
			else:
				streak_feedback = {
					"should_show": true,
					"feedback_key": "sustained",
					"title": "Hoy sostuviste tu racha",
					"message": "Vas %d %s seguidos." % [
						current_count,
						"dia" if current_count == 1 else "dias"
					],
					"current_count": current_count,
					"best_count": int(updated_streak_state.get("best_count", 0))
				}
	_save_manager.sync_runtime_progress_to_current_save()
	_append_completed_level_history(track_key, level_number)
	_write_progress_event_to_disk("level_completed")
	return {
		"streak_state": updated_streak_state,
		"streak_feedback": streak_feedback
	}


func record_question_session_completed(question_count: int, score: int) -> void:
	if question_count < 1:
		return

	Global.record_streak_activity(
		"question_session_completed",
		{
			"question_count": question_count,
			"score": score
		}
	)
	_save_manager.sync_runtime_progress_to_current_save()
	_append_completed_question_history(question_count, score)
	_write_progress_event_to_disk("question_session_completed")


func record_manual_save() -> void:
	_save_manager.sync_runtime_progress_to_current_save()
	var resume_state: Dictionary = get_resume_state()
	append_history("Guardado manual", _build_manual_save_metadata(resume_state))
	_write_progress_event_to_disk("manual_save")


func append_history(message: String, metadata: Dictionary = {}) -> void:
	var stored_history_entries: Variant = _save_manager.save_data.get("history", [])
	var history_entries: Array = stored_history_entries if stored_history_entries is Array else []
	history_entries.push_front(_build_history_entry(message, metadata))
	if history_entries.size() > _save_manager.HISTORY_LIMIT:
		history_entries = history_entries.slice(0, _save_manager.HISTORY_LIMIT)
	_save_manager.save_data["history"] = history_entries
	_get_write_coordinator().mark_dirty()


func repair_resume_state() -> bool:
	var save_data_normalizer = _get_save_data_normalizer()
	var stored_resume_state: Dictionary = save_data_normalizer.normalize_resume_state(
		_save_manager.save_data.get("resume_state", {})
	)
	var repaired_resume_state: Dictionary = _resolve_resume_state_with_history_fallback(
		stored_resume_state
	)
	if stored_resume_state == repaired_resume_state:
		return false
	_save_manager.save_data["resume_state"] = repaired_resume_state
	_get_write_coordinator().mark_dirty()
	return true


func set_resume_state(raw_resume_state: Dictionary) -> void:
	var save_data_normalizer = _get_save_data_normalizer()
	var resume_state_to_store: Dictionary = save_data_normalizer.normalize_resume_state(
		raw_resume_state
	)
	var current_resume_state: Dictionary = save_data_normalizer.normalize_resume_state(
		_save_manager.save_data.get("resume_state", {})
	)
	_save_manager.save_data["resume_state"] = resume_state_to_store
	if current_resume_state == resume_state_to_store:
		return
	_get_write_coordinator().mark_dirty()


func _should_preserve_current_level_resume(allow_level_downgrade: bool) -> bool:
	if allow_level_downgrade:
		return false
	var current_resume_state: Dictionary = get_resume_state()
	return (
		str(current_resume_state.get("context", _save_manager.RESUME_CONTEXT_HUB))
		== _save_manager.RESUME_CONTEXT_LEVEL
	)


func _build_resume_state_for_book(track_key: String) -> Dictionary:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	return {
		"context": _save_manager.RESUME_CONTEXT_BOOK,
		"track_key": track_key,
		"scene_path": str(track_definition.get("book_scene_path", "")).strip_edges(),
		"level_number": clampi(Global.current_level, 1, Global.get_track_level_count(track_key))
	}


func _build_resume_state_for_level(track_key: String, level_number: int) -> Dictionary:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	return {
		"context": _save_manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": str(track_definition.get("level_scene_path", "")).strip_edges(),
		"level_number": clampi(level_number, 1, Global.get_track_level_count(track_key))
	}


func _clear_partial_progress_and_advance_resume(track_key: String, level_number: int) -> void:
	Global.clear_partial_level_state(track_key, level_number)
	set_resume_after_level_completed(track_key, level_number)


func _append_completed_level_history(track_key: String, level_number: int) -> void:
	append_history(
		_build_completed_level_history_message(track_key, level_number),
		{
			"type": "level_completed",
			"track": track_key,
			"level": level_number
		}
	)


func _append_completed_question_history(question_count: int, score: int) -> void:
	append_history(
		"Sesion de preguntas completada (%d/%d)" % [score, question_count],
		{
			"type": "question_session_completed",
			"question_count": question_count,
			"score": score
		}
	)


func _build_completed_level_history_message(track_key: String, level_number: int) -> String:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	var track_label := str(track_definition.get("label", track_key)).strip_edges()
	return "Completaste %s - capitulo %d" % [
		track_label if not track_label.is_empty() else track_key,
		level_number
	]
func _build_manual_save_metadata(resume_state: Dictionary) -> Dictionary:
	return {
		"type": "manual_save",
		"context": str(resume_state.get("context", _save_manager.RESUME_CONTEXT_HUB)),
		"track": str(resume_state.get("track_key", "")),
		"level": int(resume_state.get("level_number", Global.current_level))
	}


func _resolve_resume_state_with_history_fallback(normalized_resume_state: Dictionary) -> Dictionary:
	var context: String = str(
		normalized_resume_state.get("context", _save_manager.RESUME_CONTEXT_HUB)
	)
	if context == _save_manager.RESUME_CONTEXT_LEVEL:
		return normalized_resume_state
	var history_resume_state: Dictionary = _find_resume_state_in_history()
	if history_resume_state.is_empty():
		return normalized_resume_state
	return history_resume_state


func _find_resume_state_in_history() -> Dictionary:
	var stored_history_entries: Variant = _save_manager.save_data.get("history", [])
	if not stored_history_entries is Array:
		return {}

	for history_entry in stored_history_entries:
		var metadata: Dictionary = _read_history_metadata(history_entry)
		if metadata.is_empty():
			continue

		var entry_type: String = str(metadata.get("type", "")).strip_edges()
		match entry_type:
			"new_game":
				return {}
			"manual_save":
				var manual_resume_state: Dictionary = (
					_build_resume_state_from_manual_save_history(metadata)
				)
				if not manual_resume_state.is_empty():
					return manual_resume_state
			"level_completed":
				var completed_resume_state: Dictionary = (
					_build_resume_state_after_completed_level_history(metadata)
				)
				if not completed_resume_state.is_empty():
					return completed_resume_state
	return {}


func _build_resume_state_from_manual_save_history(metadata: Dictionary) -> Dictionary:
	var context: String = str(metadata.get("context", "")).strip_edges()
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	if context != _save_manager.RESUME_CONTEXT_LEVEL:
		return {}
	return _build_resume_state_from_saved_level(track_key, int(metadata.get("level", 1)))


func _build_resume_state_after_completed_level_history(metadata: Dictionary) -> Dictionary:
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	var completed_level: int = clampi(
		int(metadata.get("level", 1)),
		1,
		Global.get_track_level_count(track_key)
	)
	if GameTrackCatalog.get_track_definition(track_key).is_empty():
		return {}
	if not _is_saved_level_completed(track_key, completed_level):
		return {}
	if completed_level >= Global.get_track_level_count(track_key):
		return _get_save_data_normalizer().default_resume_state()
	return _build_resume_state_from_saved_level(track_key, completed_level + 1)


func _build_resume_state_from_saved_level(track_key: String, level_number: int) -> Dictionary:
	var track_definition := GameTrackCatalog.get_track_definition(track_key)
	if track_definition.is_empty():
		return {}
	return {
		"context": _save_manager.RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": str(track_definition.get("level_scene_path", "")).strip_edges(),
		"level_number": clampi(level_number, 1, Global.get_track_level_count(track_key))
	}


func _build_track_label_by_key() -> Dictionary:
	var track_label_by_key: Dictionary = {}
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key := str(track_definition.get("key", "")).strip_edges()
		if track_key.is_empty():
			continue
		track_label_by_key[track_key] = str(track_definition.get("label", "")).strip_edges()
	return track_label_by_key


func _is_saved_level_completed(track_key: String, level_number: int) -> bool:
	var stored_progress: Variant = _save_manager.save_data.get("progress", {})
	if not stored_progress is Dictionary:
		return false
	var stored_track_progress: Variant = stored_progress.get(track_key, [])
	if not stored_track_progress is Array:
		return false
	var level_index: int = level_number - 1
	if level_index < 0 or level_index >= stored_track_progress.size():
		return false
	return bool(stored_track_progress[level_index])


func _history_has_gameplay_progress(raw_history: Variant) -> bool:
	if not raw_history is Array:
		return false
	for history_entry in raw_history:
		var metadata: Dictionary = _read_history_metadata(history_entry)
		if metadata.is_empty():
			continue
		if _save_manager.GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
			return true
	return false


func _read_history_metadata(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var metadata: Variant = entry.get("metadata", {})
	return metadata if metadata is Dictionary else {}


func _write_progress_event_to_disk(reason: String) -> void:
	var write_coordinator = _get_write_coordinator()
	if write_coordinator.write_save_data(false, reason):
		_save_manager.progress_saved.emit(_save_manager.get_current_user_profile())


func _build_history_entry(message: String, metadata: Dictionary) -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	}


func _get_save_data_normalizer():
	return _save_manager.get_save_data_normalizer()


func _get_write_coordinator():
	return _save_manager.get_write_coordinator()
