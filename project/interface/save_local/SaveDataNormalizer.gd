extends RefCounted

const SaveSessionNormalizerScript := preload("res://interface/save_local/SaveSessionNormalizer.gd")

var _profile_helper
var _session_helper
var _config: Dictionary = {}
var _session_normalizer

func _init(profile_helper, session_helper, config: Dictionary):
	_profile_helper = profile_helper
	_session_helper = session_helper
	_config = config.duplicate(true)
	_session_normalizer = SaveSessionNormalizerScript.new(session_helper, _config, Callable(self, "normalize_save_meta"), Callable(self, "normalize_history"))

func default_save_data() -> Dictionary:
	return {
		"version": int(_config.get("save_version", 1)),
		"profile": {
			"username": str(_config.get("default_profile_name", "Perfil local")),
			"age": 0,
			"email": "",
			"avatar_path": "",
			"created_at": "",
			"updated_at": ""
		},
		"active_session_id": "",
		"next_session_number": 1,
		"sessions": {},
		"save_meta": default_save_meta(),
		"resume_state": default_resume_state(),
		"progress": {},
		"history": []
	}

func default_save_meta() -> Dictionary:
	return _session_helper.default_save_meta()

func normalize_save_data(raw_data: Dictionary) -> Dictionary:
	if raw_data.has("users"):
		raw_data = migrate_legacy_save_data(raw_data)
	var normalized: Dictionary = default_save_data()
	normalized["version"] = int(raw_data.get("version", int(_config.get("save_version", 1))))
	var raw_profile: Variant = raw_data.get("profile", {})
	if raw_profile is Dictionary:
		normalized["profile"] = normalize_profile_data(raw_profile)
	var raw_progress: Variant = raw_data.get("progress", {})
	if raw_progress is Dictionary:
		normalized["progress"] = raw_progress
	var raw_save_meta: Variant = raw_data.get("save_meta", {})
	if raw_save_meta is Dictionary:
		normalized["save_meta"] = normalize_save_meta(raw_save_meta)
	var raw_resume_state: Variant = raw_data.get("resume_state", {})
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = normalize_resume_state(raw_resume_state)
	normalized["history"] = normalize_history(raw_data.get("history", []))
	var raw_sessions: Variant = raw_data.get("sessions", {})
	if raw_data.has("sessions") and raw_sessions is Dictionary:
		normalized["sessions"] = normalize_sessions(raw_sessions)
	if normalized.get("sessions", {}).is_empty():
		var migrated_session: Dictionary = migrate_single_session_data(raw_data)
		if not migrated_session.is_empty():
			var migrated_session_id: String = str(migrated_session.get("id", "%s0001" % str(_config.get("session_id_prefix", "session_"))))
			var sessions: Dictionary = normalized.get("sessions", {})
			sessions[migrated_session_id] = normalize_session_data(migrated_session, migrated_session_id)
			normalized["sessions"] = sessions
			normalized["active_session_id"] = migrated_session_id
			normalized["next_session_number"] = 2
	var next_session_number: int = max(1, int(raw_data.get("next_session_number", normalized.get("next_session_number", 1))))
	var normalized_sessions: Dictionary = normalized.get("sessions", {})
	next_session_number = max(next_session_number, normalized_sessions.size() + 1)
	normalized["next_session_number"] = next_session_number
	normalized["active_session_id"] = sanitize_active_session_id(str(raw_data.get("active_session_id", normalized.get("active_session_id", ""))).strip_edges(), normalized_sessions)
	return normalized

func default_resume_state() -> Dictionary:
	return _session_normalizer.default_resume_state()

func normalize_resume_state(raw_resume_state: Dictionary) -> Dictionary:
	return _session_normalizer.normalize_resume_state(raw_resume_state)

func default_session_data(session_id: String = "", title: String = "", created_at: String = "") -> Dictionary:
	return _session_normalizer.default_session_data(session_id, title, created_at)

func normalize_session_data(raw_session: Dictionary, session_id: String = "") -> Dictionary:
	return _session_normalizer.normalize_session_data(raw_session, session_id)

func normalize_sessions(raw_sessions: Variant) -> Dictionary:
	return _session_normalizer.normalize_sessions(raw_sessions)

func migrate_single_session_data(raw_data: Dictionary) -> Dictionary:
	return _session_normalizer.migrate_single_session_data(raw_data)

func sanitize_active_session_id(active_session_id: String, sessions: Dictionary) -> String:
	return _session_normalizer.sanitize_active_session_id(active_session_id, sessions)

func find_most_recent_session_id(sessions: Dictionary) -> String:
	return _session_normalizer.find_most_recent_session_id(sessions)

func migrate_legacy_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized: Dictionary = default_save_data()
	var selected_user: Dictionary = {}
	var raw_users: Variant = raw_data.get("users", {})
	var last_user_key: String = str(raw_data.get("last_user", ""))
	if raw_users is Dictionary:
		if raw_users.has(last_user_key) and raw_users[last_user_key] is Dictionary:
			selected_user = raw_users[last_user_key]
		elif raw_users.size() > 0:
			var first_key: Variant = raw_users.keys()[0]
			if raw_users[first_key] is Dictionary:
				selected_user = raw_users[first_key]
	if selected_user.is_empty():
		return normalized
	normalized["profile"] = normalize_profile_data({
		"username": selected_user.get("username", _config.get("default_profile_name", "Perfil local")),
		"age": selected_user.get("age", 0),
		"email": selected_user.get("email", ""),
		"avatar_path": selected_user.get("avatar_path", ""),
		"created_at": selected_user.get("created_at", ""),
		"updated_at": selected_user.get("updated_at", "")
	})
	var migrated_progress: Variant = selected_user.get("progress", {})
	if migrated_progress is Dictionary:
		normalized["progress"] = migrated_progress
	normalized["save_meta"] = normalize_save_meta({"last_saved_at": selected_user.get("updated_at", ""), "last_saved_reason": "legacy_migration", "write_count": 0})
	normalized["history"] = normalize_history(selected_user.get("history", []))
	return normalized

func normalize_profile_data(raw_profile: Dictionary) -> Dictionary:
	return _profile_helper.normalize_profile_data(raw_profile, str(_config.get("default_profile_name", "Perfil local")))

func normalize_save_meta(raw_save_meta: Dictionary) -> Dictionary:
	return {"last_saved_at": str(raw_save_meta.get("last_saved_at", "")), "last_saved_reason": str(raw_save_meta.get("last_saved_reason", "")), "write_count": max(0, int(raw_save_meta.get("write_count", 0)))}

func normalize_history(raw_history: Variant) -> Array:
	var history: Array = []
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				history.append(entry)
	return history

