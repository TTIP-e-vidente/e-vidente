extends RefCounted


const SAVE_PATH := "user://save_data.json"
const TEMP_PATH := "user://save_data.tmp.json"
const BACKUP_PATH := "user://save_data.backup.json"
const SAVE_VERSION := 4
const DEFAULT_PROFILE_NAME := "Perfil local"

var _storage_helper: RefCounted
var _profile_helper: RefCounted
var _resume_helper: RefCounted


func _init(
	storage_helper: RefCounted,
	profile_helper: RefCounted,
	resume_helper: RefCounted
) -> void:
	_storage_helper = storage_helper
	_profile_helper = profile_helper
	_resume_helper = resume_helper


# Carga save_data desde disco. Devuelve un contexto con:
# {save_data, loaded_from, recovered_from, needs_write, rewrite_reason}
func load_from_disk() -> Dictionary:
	var context: Dictionary = {
		"save_data": default_save_data(),
		"loaded_from": "default",
		"recovered_from": "",
		"needs_write": false,
		"rewrite_reason": ""
	}
	var load_result: Dictionary = _storage_helper.load_available_save_data(
		SAVE_PATH,
		TEMP_PATH,
		BACKUP_PATH
	)

	if not bool(load_result.get("ok", false)):
		context["needs_write"] = true
		return context

	var raw_data: Dictionary = load_result.get("data", {})
	context["save_data"] = _normalize_save_data(raw_data)
	context["loaded_from"] = str(load_result.get("source", "primary"))

	if context["loaded_from"] != "primary":
		context["recovered_from"] = context["loaded_from"]
		context["needs_write"] = true

	context["rewrite_reason"] = _rewrite_reason(raw_data)
	if not str(context["rewrite_reason"]).is_empty():
		context["needs_write"] = true

	return context


# Verifica y repara la estructura interna de save_data (perfil, progreso, meta, resume).
# Muta save_data en-lugar. Devuelve true si hubo cambios que requieren reescribir a disco.
func repair_structure(save_data: Dictionary) -> bool:
	var changed: bool = _apply_profile_shape(save_data)
	if _apply_progress_and_history_shape(save_data):
		changed = true
	if _apply_save_meta_shape(save_data):
		changed = true
	if _apply_resume_state_shape(save_data):
		changed = true
	return changed


# Save data por defecto cuando no hay archivo en disco o la carga falla.
func default_save_data() -> Dictionary:
	return _build_default_save_data()


func _apply_profile_shape(save_data: Dictionary) -> bool:
	var changed := false
	var stored_profile: Variant = save_data.get("profile", {})
	if not stored_profile is Dictionary:
		stored_profile = {}
		changed = true

	var profile: Dictionary = _profile_helper.normalize_profile_data(stored_profile, DEFAULT_PROFILE_NAME)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
		changed = true

	var created_at: String = str(profile.get("created_at", ""))
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(false, true)
		profile["created_at"] = created_at
		changed = true

	if str(profile.get("updated_at", "")).is_empty():
		profile["updated_at"] = created_at
		changed = true

	save_data["profile"] = profile
	return changed


func _apply_progress_and_history_shape(save_data: Dictionary) -> bool:
	var changed := false
	if not save_data.get("progress", {}) is Dictionary:
		save_data["progress"] = {}
		changed = true
	if not save_data.get("history", []) is Array:
		save_data["history"] = []
		changed = true
	return changed


func _apply_save_meta_shape(save_data: Dictionary) -> bool:
	var stored: Variant = save_data.get("save_meta", {})
	var changed: bool = not stored is Dictionary
	save_data["save_meta"] = _normalize_save_meta(stored)
	return changed


func _apply_resume_state_shape(save_data: Dictionary) -> bool:
	var stored: Variant = save_data.get("resume_state", {})
	if not stored is Dictionary:
		save_data["resume_state"] = _resume_helper.default_resume_state()
		return true
	save_data["resume_state"] = _resume_helper.normalize_resume_state(stored)
	return false


# --- Schema: normalización y defaults ---

func _normalize_save_meta(raw_save_meta: Variant) -> Dictionary:
	if not raw_save_meta is Dictionary:
		return _default_save_meta()
	return {
		"last_saved_at": str(raw_save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(raw_save_meta.get("last_saved_reason", "")),
		"write_count": max(0, int(raw_save_meta.get("write_count", 0)))
	}


static func _default_save_meta() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0
	}


func _build_default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {
			"username": DEFAULT_PROFILE_NAME,
			"age": 0,
			"email": "",
			"avatar_path": "",
			"created_at": "",
			"updated_at": ""
		},
		"save_meta": _default_save_meta(),
		"resume_state": _resume_helper.default_resume_state().duplicate(true),
		"progress": {},
		"history": []
	}


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var migrated_data: Dictionary = raw_data
	if raw_data.has("users"):
		migrated_data = _migrate_legacy_save_data(raw_data)
	var source_data: Dictionary = _flatten_legacy_sessions_if_needed(migrated_data)
	var normalized: Dictionary = _build_default_save_data()
	normalized["version"] = int(source_data.get("version", SAVE_VERSION))

	var raw_profile: Variant = source_data.get("profile", {})
	if raw_profile is Dictionary:
		normalized["profile"] = _profile_helper.normalize_profile_data(raw_profile, DEFAULT_PROFILE_NAME)

	var raw_progress: Variant = source_data.get("progress", {})
	if raw_progress is Dictionary:
		normalized["progress"] = (raw_progress as Dictionary).duplicate(true)

	normalized["save_meta"] = _normalize_save_meta(source_data.get("save_meta", {}))

	var raw_resume_state: Variant = source_data.get("resume_state", {})
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = (raw_resume_state as Dictionary).duplicate(true)

	normalized["history"] = _normalize_history(source_data.get("history", []))
	return normalized


func _rewrite_reason(raw_data: Dictionary) -> String:
	if raw_data.has("users"):
		return "legacy_migration"
	if raw_data.has("sessions"):
		return "schema_simplification"
	if raw_data.has("active_session_id") or raw_data.has("next_session_number"):
		return "schema_simplification"
	return ""


func _normalize_history(raw_history: Variant) -> Array:
	var history: Array = []
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				history.append((entry as Dictionary).duplicate(true))
	return history


# --- Migración de formatos legacy ---

func _migrate_legacy_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized: Dictionary = _build_default_save_data()
	var selected_user: Dictionary = _resolve_selected_legacy_user(raw_data)
	if selected_user.is_empty():
		return normalized

	normalized["profile"] = _profile_helper.normalize_profile_data(
		{
			"username": selected_user.get("username", DEFAULT_PROFILE_NAME),
			"age": selected_user.get("age", 0),
			"email": selected_user.get("email", ""),
			"avatar_path": selected_user.get("avatar_path", ""),
			"created_at": selected_user.get("created_at", ""),
			"updated_at": selected_user.get("updated_at", "")
		},
		DEFAULT_PROFILE_NAME
	)

	var migrated_progress: Variant = selected_user.get("progress", {})
	if migrated_progress is Dictionary:
		normalized["progress"] = (migrated_progress as Dictionary).duplicate(true)

	normalized["save_meta"] = _normalize_save_meta(
		{
			"last_saved_at": selected_user.get("updated_at", ""),
			"last_saved_reason": "legacy_migration",
			"write_count": 0
		}
	)
	normalized["history"] = _normalize_history(selected_user.get("history", []))
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

	flattened["history"] = _normalize_history(selected_session.get("history", []))
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
