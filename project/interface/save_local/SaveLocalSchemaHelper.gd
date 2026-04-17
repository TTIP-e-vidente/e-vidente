extends RefCounted


var _profile_helper: RefCounted
var _save_version: int
var _default_profile_name: String


func _init(profile_helper: RefCounted, save_version: int, default_profile_name: String) -> void:
	_profile_helper = profile_helper
	_save_version = save_version
	_default_profile_name = default_profile_name


func build_default_save_data(default_resume_state: Dictionary) -> Dictionary:
	return {
		"version": _save_version,
		"profile": _build_default_profile_data(),
		"save_meta": default_save_meta(),
		"resume_state": default_resume_state.duplicate(true),
		"progress": {},
		"history": []
	}


func default_save_meta() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0
	}


func normalize_profile_data(raw_profile: Dictionary) -> Dictionary:
	return _profile_helper.normalize_profile_data(raw_profile, _default_profile_name)


func normalize_save_data(raw_data: Dictionary, default_resume_state: Dictionary) -> Dictionary:
	var source_data: Dictionary = _flatten_legacy_sessions_if_needed(
		_migrate_legacy_root_if_needed(raw_data, default_resume_state)
	)
	var normalized: Dictionary = build_default_save_data(default_resume_state)
	normalized["version"] = int(source_data.get("version", _save_version))

	var raw_profile: Variant = source_data.get("profile", {})
	if raw_profile is Dictionary:
		normalized["profile"] = normalize_profile_data(raw_profile)

	var raw_progress: Variant = source_data.get("progress", {})
	if raw_progress is Dictionary:
		normalized["progress"] = (raw_progress as Dictionary).duplicate(true)

	normalized["save_meta"] = normalize_save_meta(source_data.get("save_meta", {}))

	var raw_resume_state: Variant = source_data.get("resume_state", {})
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = (raw_resume_state as Dictionary).duplicate(true)

	normalized["history"] = normalize_history(source_data.get("history", []))
	return normalized


func rewrite_reason(raw_data: Dictionary) -> String:
	if raw_data.has("users"):
		return "legacy_migration"
	if raw_data.has("sessions"):
		return "schema_simplification"
	if raw_data.has("active_session_id") or raw_data.has("next_session_number"):
		return "schema_simplification"
	return ""


func normalize_save_meta(raw_save_meta: Variant) -> Dictionary:
	if not raw_save_meta is Dictionary:
		return default_save_meta()
	return {
		"last_saved_at": str(raw_save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(raw_save_meta.get("last_saved_reason", "")),
		"write_count": max(0, int(raw_save_meta.get("write_count", 0)))
	}


func normalize_history(raw_history: Variant) -> Array:
	var history: Array = []
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				history.append((entry as Dictionary).duplicate(true))
	return history


func normalize_save_name(title: String) -> String:
	var clean_title: String = title.strip_edges()
	for whitespace in ["\n", "\r", "\t"]:
		clean_title = clean_title.replace(whitespace, " ")
	while clean_title.contains("  "):
		clean_title = clean_title.replace("  ", " ")
	return clean_title


func count_completed_progress_track(track_progress: Variant) -> int:
	var completed := 0
	if track_progress is Array:
		for entry in track_progress:
			if bool(entry):
				completed += 1
	return completed


func _build_default_profile_data() -> Dictionary:
	return {
		"username": _default_profile_name,
		"age": 0,
		"email": "",
		"avatar_path": "",
		"created_at": "",
		"updated_at": ""
	}


func _migrate_legacy_root_if_needed(
	raw_data: Dictionary,
	default_resume_state: Dictionary
) -> Dictionary:
	if not raw_data.has("users"):
		return raw_data
	return _migrate_legacy_save_data(raw_data, default_resume_state)


func _migrate_legacy_save_data(
	raw_data: Dictionary,
	default_resume_state: Dictionary
) -> Dictionary:
	var normalized: Dictionary = build_default_save_data(default_resume_state)
	var selected_user: Dictionary = _resolve_selected_legacy_user(raw_data)
	if selected_user.is_empty():
		return normalized

	normalized["profile"] = normalize_profile_data(
		{
			"username": selected_user.get("username", _default_profile_name),
			"age": selected_user.get("age", 0),
			"email": selected_user.get("email", ""),
			"avatar_path": selected_user.get("avatar_path", ""),
			"created_at": selected_user.get("created_at", ""),
			"updated_at": selected_user.get("updated_at", "")
		}
	)

	var migrated_progress: Variant = selected_user.get("progress", {})
	if migrated_progress is Dictionary:
		normalized["progress"] = (migrated_progress as Dictionary).duplicate(true)

	normalized["save_meta"] = normalize_save_meta(
		{
			"last_saved_at": selected_user.get("updated_at", ""),
			"last_saved_reason": "legacy_migration",
			"write_count": 0
		}
	)
	normalized["history"] = normalize_history(selected_user.get("history", []))
	return normalized


func _resolve_selected_legacy_user(raw_data: Dictionary) -> Dictionary:
	var raw_users: Variant = raw_data.get("users", {})
	if not raw_users is Dictionary:
		return {}

	var users: Dictionary = raw_users
	var last_user_key: String = str(raw_data.get("last_user", ""))
	if users.has(last_user_key) and users[last_user_key] is Dictionary:
		return users[last_user_key]
	if users.is_empty():
		return {}

	var first_key: Variant = users.keys()[0]
	return users[first_key] if users[first_key] is Dictionary else {}


func _flatten_legacy_sessions_if_needed(raw_data: Dictionary) -> Dictionary:
	var raw_sessions: Variant = raw_data.get("sessions", {})
	if not raw_sessions is Dictionary:
		return raw_data

	var selected_session: Dictionary = _select_legacy_session_state(
		raw_sessions,
		str(raw_data.get("active_session_id", "")).strip_edges()
	)
	if selected_session.is_empty():
		return raw_data

	var flattened: Dictionary = raw_data.duplicate(true)
	var raw_progress: Variant = selected_session.get("progress", {})
	if raw_progress is Dictionary:
		flattened["progress"] = (raw_progress as Dictionary).duplicate(true)

	var raw_save_meta: Variant = selected_session.get("save_meta", {})
	if raw_save_meta is Dictionary:
		flattened["save_meta"] = (raw_save_meta as Dictionary).duplicate(true)

	var raw_resume_state: Variant = selected_session.get("resume_state", {})
	if raw_resume_state is Dictionary:
		flattened["resume_state"] = (raw_resume_state as Dictionary).duplicate(true)

	flattened["history"] = normalize_history(selected_session.get("history", []))
	return flattened


func _select_legacy_session_state(
	raw_sessions: Dictionary,
	active_session_id: String
) -> Dictionary:
	if raw_sessions.has(active_session_id) and raw_sessions[active_session_id] is Dictionary:
		return raw_sessions[active_session_id]

	var selected_session: Dictionary = {}
	var selected_updated_at: String = ""
	for raw_session_id in raw_sessions.keys():
		var legacy_session: Variant = raw_sessions[raw_session_id]
		if not legacy_session is Dictionary:
			continue
		var updated_at: String = _last_updated_at(legacy_session)
		if selected_session.is_empty() or updated_at > selected_updated_at:
			selected_session = legacy_session
			selected_updated_at = updated_at
	return selected_session


func _last_updated_at(state_data: Dictionary) -> String:
	var updated_at: String = str(state_data.get("updated_at", ""))
	if not updated_at.is_empty():
		return updated_at
	var save_meta: Variant = state_data.get("save_meta", {})
	if save_meta is Dictionary:
		updated_at = str(save_meta.get("last_saved_at", ""))
	if not updated_at.is_empty():
		return updated_at
	return str(state_data.get("created_at", ""))