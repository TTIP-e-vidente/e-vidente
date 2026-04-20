extends RefCounted

const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveDataSchemaScript := preload(
	"res://interface/save_local/data/SaveDataSchema.gd"
)

const SAVE_PATH := "user://save_data.json"
const TEMP_SAVE_PATH := "user://save_data.tmp.json"
const BACKUP_SAVE_PATH := "user://save_data.backup.json"
const DEFAULT_PROFILE_NAME := SaveDataSchemaScript.DEFAULT_PROFILE_NAME
const SAVE_VERSION := SaveDataSchemaScript.SAVE_VERSION

var _profile_helper: RefCounted
var _schema: RefCounted
var loaded_from: String = "default"
var recovered_from: String = ""
var needs_write: bool = false
var rewrite_reason: String = ""


func _init() -> void:
	_profile_helper = SaveLocalProfileHelperScript.new()
	_schema = SaveDataSchemaScript.new()


func load_data() -> Dictionary:
	_reset_load_context()

	var raw_save: Variant = _read_first_valid_file()
	if not raw_save is Dictionary:
		needs_write = true
		return _schema.default_save_data()

	var loaded_save: Dictionary = raw_save
	if loaded_from != "primary":
		recovered_from = loaded_from
		needs_write = true

	rewrite_reason = _rewrite_reason(loaded_save)
	if not rewrite_reason.is_empty():
		needs_write = true

	return _normalize_loaded_data(loaded_save)


func repair_structure(save_snapshot: Dictionary) -> bool:
	var changed := false

	var stored_profile: Variant = save_snapshot.get("profile", {})
	if not stored_profile is Dictionary:
		stored_profile = {}
		changed = true

	var profile: Dictionary = _profile_helper.normalize_profile_data(
		stored_profile,
		DEFAULT_PROFILE_NAME
	)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
		changed = true
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = Time.get_datetime_string_from_system(false, true)
		changed = true
	if str(profile.get("updated_at", "")).is_empty():
		profile["updated_at"] = str(profile.get("created_at", ""))
		changed = true
	save_snapshot["profile"] = profile

	if not save_snapshot.get("progress", {}) is Dictionary:
		save_snapshot["progress"] = {}
		changed = true

	if not save_snapshot.get("history", []) is Array:
		save_snapshot["history"] = []
		changed = true

	if not save_snapshot.get("save_meta", {}) is Dictionary:
		save_snapshot["save_meta"] = _empty_save_meta()
		changed = true
	else:
		save_snapshot["save_meta"] = _schema.normalize_save_meta(
			save_snapshot.get("save_meta", {})
		)

	return changed


func _reset_load_context() -> void:
	loaded_from = "default"
	recovered_from = ""
	needs_write = false
	rewrite_reason = ""


func _read_first_valid_file() -> Variant:
	var raw_save: Variant = _read_json_file(SAVE_PATH)
	if raw_save is Dictionary:
		loaded_from = "primary"
		return raw_save

	raw_save = _read_json_file(TEMP_SAVE_PATH)
	if raw_save is Dictionary:
		loaded_from = "temp"
		return raw_save

	raw_save = _read_json_file(BACKUP_SAVE_PATH)
	if raw_save is Dictionary:
		loaded_from = "backup"
		return raw_save

	return null


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text := file.get_as_text()
	file = null
	if text.strip_edges().is_empty():
		return null

	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	if json.data is Dictionary:
		return (json.data as Dictionary).duplicate(true)
	return null


func _normalize_loaded_data(raw: Dictionary) -> Dictionary:
	var migrated: Dictionary = raw
	if raw.has("users"):
		migrated = _migrate_legacy(raw)

	var source: Dictionary = _flatten_legacy_sessions(migrated)
	var normalized: Dictionary = _schema.default_save_data()
	normalized["version"] = int(source.get("version", SAVE_VERSION))

	var source_profile: Variant = source.get("profile", {})
	if source_profile is Dictionary:
		normalized["profile"] = _profile_helper.normalize_profile_data(
			source_profile,
			DEFAULT_PROFILE_NAME
		)

	var source_progress: Variant = source.get("progress", {})
	if source_progress is Dictionary:
		normalized["progress"] = (source_progress as Dictionary).duplicate(true)

	normalized["save_meta"] = _schema.normalize_save_meta(source.get("save_meta", {}))

	var source_resume_state: Variant = source.get("resume_state", {})
	if source_resume_state is Dictionary:
		normalized["resume_state"] = (source_resume_state as Dictionary).duplicate(true)

	normalized["history"] = _schema.normalize_history(source.get("history", []))
	return normalized


func _rewrite_reason(raw: Dictionary) -> String:
	if raw.has("users"):
		return "legacy_migration"
	if raw.has("sessions") or raw.has("active_session_id") or raw.has("next_session_number"):
		return "schema_simplification"
	return ""


func _migrate_legacy(raw: Dictionary) -> Dictionary:
	var normalized: Dictionary = _schema.default_save_data()
	var user: Dictionary = _resolve_legacy_user(raw)
	if user.is_empty():
		return normalized

	normalized["profile"] = _profile_helper.normalize_profile_data({
		"username": user.get("username", DEFAULT_PROFILE_NAME),
		"age": user.get("age", 0),
		"email": user.get("email", ""),
		"avatar_path": user.get("avatar_path", ""),
		"created_at": user.get("created_at", ""),
		"updated_at": user.get("updated_at", "")
	}, DEFAULT_PROFILE_NAME)

	var legacy_progress: Variant = user.get("progress", {})
	if legacy_progress is Dictionary:
		normalized["progress"] = (legacy_progress as Dictionary).duplicate(true)

	normalized["save_meta"] = _schema.normalize_save_meta({
		"last_saved_at": user.get("updated_at", ""),
		"last_saved_reason": "legacy_migration",
		"write_count": 0
	})
	normalized["history"] = _schema.normalize_history(user.get("history", []))
	return normalized


func _resolve_legacy_user(raw: Dictionary) -> Dictionary:
	var users: Variant = raw.get("users", {})
	if not users is Dictionary:
		return {}

	var last_key: String = str(raw.get("last_user", ""))
	if users.has(last_key) and users[last_key] is Dictionary:
		return users[last_key]
	if users.is_empty():
		return {}

	var first_key: Variant = users.keys()[0]
	return users[first_key] if users[first_key] is Dictionary else {}


func _flatten_legacy_sessions(raw: Dictionary) -> Dictionary:
	var sessions: Variant = raw.get("sessions", {})
	if not sessions is Dictionary:
		return raw

	var active_id: String = str(raw.get("active_session_id", "")).strip_edges()
	var selected: Dictionary = {}
	if sessions.has(active_id) and sessions[active_id] is Dictionary:
		selected = sessions[active_id]
	else:
		var newest_saved_at: String = ""
		for session_id in sessions.keys():
			var session_data: Variant = sessions[session_id]
			if not session_data is Dictionary:
				continue

			var raw_meta: Variant = session_data.get("save_meta", {})
			var last_saved_at: String = ""
			if raw_meta is Dictionary:
				last_saved_at = str(raw_meta.get("last_saved_at", ""))

			var updated_at: String = str(session_data.get("updated_at", last_saved_at))
			if updated_at.is_empty():
				updated_at = str(session_data.get("created_at", ""))

			if selected.is_empty() or updated_at > newest_saved_at:
				selected = session_data
				newest_saved_at = updated_at

	if selected.is_empty():
		return raw

	var flat: Dictionary = raw.duplicate(true)

	var selected_progress: Variant = selected.get("progress", {})
	if selected_progress is Dictionary:
		flat["progress"] = (selected_progress as Dictionary).duplicate(true)

	var selected_save_meta: Variant = selected.get("save_meta", {})
	if selected_save_meta is Dictionary:
		flat["save_meta"] = (selected_save_meta as Dictionary).duplicate(true)

	var selected_resume_state: Variant = selected.get("resume_state", {})
	if selected_resume_state is Dictionary:
		flat["resume_state"] = (selected_resume_state as Dictionary).duplicate(true)

	flat["history"] = _schema.normalize_history(selected.get("history", []))
	return flat


func _empty_save_meta() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0
	}