extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveLocalSchemaHelperScript := preload(
	"res://interface/save_local/SaveLocalSchemaHelper.gd"
)
const SaveLocalResumeHelperScript := preload(
	"res://interface/save_local/SaveLocalResumeHelper.gd"
)
const SaveLocalStorageHelperScript := preload(
	"res://interface/save_local/persistence/SaveLocalStorageHelper.gd"
)

@warning_ignore("unused_signal")
signal user_registered(profile: Dictionary)
signal user_logged_in(profile: Dictionary)
signal user_logged_out()
@warning_ignore("unused_signal")
signal progress_saved(profile: Dictionary)
@warning_ignore("unused_signal")
signal progress_loaded(profile: Dictionary)
signal save_status_changed(status: Dictionary)

const SAVE_PATH := "user://save_data.json"
const TEMP_SAVE_PATH := "user://save_data.tmp.json"
const BACKUP_SAVE_PATH := "user://save_data.backup.json"
const AVATARS_DIR := "user://avatars"
const SAVE_VERSION := 4
const HISTORY_LIMIT := 25
const DEFAULT_PROFILE_NAME := "Perfil local"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const RESUME_CONTEXT_HUB := "hub"
const RESUME_CONTEXT_BOOK := "book"
const RESUME_CONTEXT_LEVEL := "level"
const LOCAL_SAVE_ID := "local_save"
const LOCAL_SAVE_TITLE := "Partida actual"
const LOCAL_PROFILE_KEY := "local_profile"
const SAVE_NAME_MIN_LENGTH := 3
const SAVE_NAME_MAX_LENGTH := 40
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]
const DEBUG_STREAK_LOG_PREFIX := "[STREAK_DEBUG]"

var save_data: Dictionary = {}
var has_unsaved_changes: bool = false
var runtime_save_status: Dictionary = {
	"state": "idle",
	"last_loaded_from": "default",
	"recovered_from": "",
	"last_error": ""
}

var _profile_helper: RefCounted
var _schema_helper: RefCounted
var _resume_helper: RefCounted
var _storage_helper: RefCounted


func _init() -> void:
	_profile_helper = SaveLocalProfileHelperScript.new()
	_schema_helper = SaveLocalSchemaHelperScript.new(
		_profile_helper,
		SAVE_VERSION,
		DEFAULT_PROFILE_NAME
	)
	_resume_helper = SaveLocalResumeHelperScript.new(
		ARCHIVERO_SCENE,
		RESUME_CONTEXT_HUB,
		RESUME_CONTEXT_BOOK,
		RESUME_CONTEXT_LEVEL,
		HISTORY_LIMIT,
		GAMEPLAY_HISTORY_TYPES
	)
	_storage_helper = SaveLocalStorageHelperScript.new()


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		persist_runtime_progress_to_current_save()


func load_data() -> void:
	var load_context: Dictionary = _prepare_load_context()
	_finalize_loaded_save_data(load_context)
	_import_loaded_progress(load_context)
	progress_loaded.emit(get_current_user_profile())


func register_user(
	username: String,
	_password: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return update_local_profile(username, age, email, avatar_source_path)


func login_user(_identifier: String, _password: String) -> Dictionary:
	sync_runtime_progress_from_current_save()
	var current_profile: Dictionary = get_current_user_profile()
	user_logged_in.emit(current_profile)
	return {
		"ok": true,
		"message": "La persistencia local ya esta activa en este dispositivo.",
		"profile": current_profile
	}


func logout() -> void:
	persist_runtime_progress_to_current_save()
	user_logged_out.emit()


func update_local_profile(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	var validation: Dictionary = _profile_helper.validate_profile(
		username,
		age,
		email,
		avatar_source_path
	)
	if not bool(validation.get("ok", false)):
		return validation

	var clean_profile_update: Dictionary = _build_clean_profile_update(
		username,
		age,
		email,
		avatar_source_path
	)
	var profile: Dictionary = get_current_user_profile()
	var previous_avatar_path: String = str(profile.get("avatar_path", "")).strip_edges()
	var avatar_result: Dictionary = _apply_profile_avatar_change(
		profile,
		str(clean_profile_update.get("avatar_path", "")),
		previous_avatar_path
	)
	if not bool(avatar_result.get("ok", false)):
		return avatar_result

	_apply_profile_identity_changes(profile, clean_profile_update)
	_stamp_profile_timestamps(profile)
	save_data["profile"] = profile
	return _persist_updated_profile()


func load_avatar_texture(path: String) -> Texture2D:
	return _profile_helper.load_avatar_texture(path)


func get_current_user_avatar_texture() -> Texture2D:
	var profile: Dictionary = get_current_user_profile()
	if profile.is_empty():
		return null
	return load_avatar_texture(str(profile.get("avatar_path", "")))


func get_current_user_profile() -> Dictionary:
	var stored_profile: Variant = save_data.get("profile", {})
	if not stored_profile is Dictionary:
		return {}

	var normalized_profile: Dictionary = _schema_helper.normalize_profile_data(stored_profile)
	if str(normalized_profile.get("username", "")).is_empty():
		normalized_profile["username"] = DEFAULT_PROFILE_NAME
	return normalized_profile


func is_authenticated() -> bool:
	return not get_current_user_profile().is_empty()


func has_accounts() -> bool:
	return is_authenticated()


func get_users_count() -> int:
	return 1 if is_authenticated() else 0


func get_last_user_hint() -> String:
	return str(get_current_user_profile().get("username", DEFAULT_PROFILE_NAME))


func sync_runtime_progress_to_current_save() -> void:
	_snapshot_runtime_progress_into_save_data()
	_mark_save_dirty()


func persist_runtime_progress_to_current_save() -> void:
	sync_runtime_progress_to_current_save()
	_write_current_save_and_emit_progress_saved("progress_sync")


func sync_runtime_progress_from_current_save() -> void:
	var loaded_progress: Dictionary = _read_progress_dictionary(save_data.get("progress", {}))
	_import_progress_into_runtime(
		loaded_progress,
		"before_global_import_progress_from_current_save",
		"after_global_import_progress_from_current_save"
	)


func sync_runtime_progress_from_current_save_and_emit_signal() -> void:
	sync_runtime_progress_from_current_save()
	progress_loaded.emit(get_current_user_profile())


func reload_current_save_and_get_resume_state() -> Dictionary:
	load_data()
	sync_runtime_progress_from_current_save()
	return _apply_resume_level_to_global_state(get_resume_state())


func reload_current_save_and_get_resume_state_and_emit_signal() -> Dictionary:
	load_data()
	sync_runtime_progress_from_current_save_and_emit_signal()
	return _apply_resume_level_to_global_state(get_resume_state())


func reset_all_progress() -> Dictionary:
	var current_profile: Dictionary = get_current_user_profile()
	_reset_current_save_data(current_profile)
	if not _write_save_to_disk(false, "progress_reset"):
		return {
			"ok": false,
			"message": "No se pudo reiniciar el progreso local en disco."
		}

	progress_loaded.emit(current_profile)
	progress_saved.emit(current_profile)
	return {
		"ok": true,
		"message": "Se reinicio el progreso local.",
		"profile": current_profile
	}


func start_new_game(_save_title: String = "") -> bool:
	load_data()
	var current_profile: Dictionary = get_current_user_profile()
	_reset_current_save_data(current_profile)
	_append_history("Nueva partida iniciada", {"type": "new_game"})
	if not _write_save_to_disk(false, "new_game"):
		return false
	_emit_progress_refresh_signals()
	return true


func validate_save_name(save_title: String) -> Dictionary:
	var clean_title: String = _schema_helper.normalize_save_name(save_title)
	if clean_title.is_empty():
		return {"ok": true, "title": "", "message": ""}
	if clean_title.length() < SAVE_NAME_MIN_LENGTH:
		return {
			"ok": false,
			"title": clean_title,
			"message": "Usa al menos %d caracteres para identificar la partida."
				% SAVE_NAME_MIN_LENGTH
		}
	if clean_title.length() > SAVE_NAME_MAX_LENGTH:
		return {
			"ok": false,
			"title": clean_title.left(SAVE_NAME_MAX_LENGTH),
			"message": "El nombre puede tener hasta %d caracteres." % SAVE_NAME_MAX_LENGTH
		}
	return {"ok": true, "title": clean_title, "message": ""}


func summarize_progress_data(progress: Variant) -> Dictionary:
	var progress_data: Dictionary = progress if progress is Dictionary else {}
	var summary: Dictionary = {
		"total": 0,
		"max_total": 0
	}
	for raw_track_key in GameTrackCatalog.get_track_keys():
		var track_key: String = str(raw_track_key)
		var completed_levels: int = _schema_helper.count_completed_progress_track(
			progress_data.get(track_key, [])
		)
		summary[track_key] = completed_levels
		summary["total"] = int(summary.get("total", 0)) + completed_levels
		summary["max_total"] = (
			int(summary.get("max_total", 0))
			+ Global.get_track_level_count(track_key)
		)
	return summary


func get_current_save_history() -> Array:
	return _resume_helper.get_history(save_data)


func record_manual_save() -> void:
	sync_runtime_progress_to_current_save()
	_append_history("Guardado manual", _build_manual_save_history_metadata(get_resume_state()))
	_write_current_save_and_emit_progress_saved("manual_save")


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	if not allow_level_downgrade:
		var current_resume_state: Dictionary = get_resume_state()
		if str(current_resume_state.get("context", RESUME_CONTEXT_HUB)) == RESUME_CONTEXT_LEVEL:
			return

	var resume_state: Dictionary = _resume_helper.build_resume_state_for_book(
		track_key,
		Global.current_level
	)
	_store_resume_state(resume_state)


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	var level_number_to_resume: int = Global.current_level if level_number < 1 else level_number
	var resume_state: Dictionary = _resume_helper.build_resume_state_for_level(
		track_key,
		level_number_to_resume
	)
	_store_resume_state(resume_state)


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	if level_number < Global.get_track_level_count(track_key):
		set_resume_to_level(track_key, level_number + 1)
		return
	_store_resume_state(_resume_helper.default_resume_state())


func get_resume_state() -> Dictionary:
	return _resume_helper.get_resume_state(save_data)


func get_current_resume_hint() -> String:
	return _resume_helper.format_resume_hint_from_state(get_resume_state())


func can_resume_current_save() -> bool:
	var saved_progress_summary: Dictionary = summarize_progress_data(save_data.get("progress", {}))
	if int(saved_progress_summary.get("total", 0)) > 0:
		return true

	var resume_context: String = str(get_resume_state().get("context", RESUME_CONTEXT_HUB))
	if resume_context != RESUME_CONTEXT_HUB:
		return true

	return _resume_helper.history_has_gameplay_progress(save_data.get("history", []))


func record_level_completed(track_key: String, level_number: int) -> Dictionary:
	var previous_streak_state: Dictionary = Global.get_streak_state()
	Global.clear_partial_level_state(track_key, level_number)
	set_resume_after_level_completed(track_key, level_number)

	var updated_streak_state: Dictionary = _record_level_completed_streak(
		track_key,
		level_number
	)
	var streak_feedback: Dictionary = _build_streak_feedback(
		previous_streak_state,
		updated_streak_state
	)

	sync_runtime_progress_to_current_save()
	_append_history(
		_build_level_completed_history_message(track_key, level_number),
		{
			"type": "level_completed",
			"track": track_key,
			"level": level_number
		}
	)
	_write_current_save_and_emit_progress_saved("level_completed")
	return {
		"streak_state": updated_streak_state,
		"streak_feedback": streak_feedback
	}


func record_question_session_completed(question_count: int, score: int) -> void:
	if question_count < 1:
		return

	_record_question_session_streak(question_count, score)
	sync_runtime_progress_to_current_save()
	_append_history(
		_build_question_session_history_message(question_count, score),
		{
			"type": "question_session_completed",
			"question_count": question_count,
			"score": score
		}
	)
	_write_current_save_and_emit_progress_saved("question_session_completed")


func get_save_status() -> Dictionary:
	var local_save_summary: Dictionary = get_current_save_summary()
	var available_save_count: int = list_available_saves(true).size()
	return _build_save_status_snapshot(
		_current_save_meta(),
		local_save_summary,
		available_save_count
	)


func notify_save_status_changed() -> void:
	save_status_changed.emit(get_save_status())


func get_current_save_id() -> String:
	return LOCAL_SAVE_ID if can_resume_current_save() else ""


func get_current_save_summary() -> Dictionary:
	if not can_resume_current_save():
		return {}

	return _build_current_save_summary(
		get_current_user_profile(),
		_current_save_meta(),
		get_resume_state(),
		summarize_progress_data(save_data.get("progress", {}))
	)


func list_available_saves(include_empty: bool = false) -> Array:
	var save_summary: Dictionary = get_current_save_summary()
	if save_summary.is_empty():
		return []
	if include_empty or bool(save_summary.get("can_resume", false)):
		return [save_summary]
	return []


func _prepare_load_context() -> Dictionary:
	var load_context: Dictionary = _read_save_from_disk()
	save_data = load_context.get("save_data", _default_save_data())
	load_context["needs_write"] = _repair_loaded_save_data(
		bool(load_context.get("needs_write", false))
	)
	return load_context


func _repair_loaded_save_data(needs_write: bool) -> bool:
	var should_rewrite: bool = needs_write
	if _ensure_local_save_structure():
		should_rewrite = true
	if _resume_helper.repair_resume_state(save_data):
		_mark_save_dirty()
		should_rewrite = true
	return should_rewrite


func _finalize_loaded_save_data(load_context: Dictionary) -> void:
	var loaded_from: String = str(load_context.get("loaded_from", "default"))
	var recovered_from: String = str(load_context.get("recovered_from", ""))
	var rewrite_reason: String = str(load_context.get("rewrite_reason", ""))
	if bool(load_context.get("needs_write", false)):
		_rewrite_repaired_save_data(loaded_from, recovered_from, rewrite_reason)
		return

	has_unsaved_changes = false
	_emit_save_status("ready", loaded_from)


func _import_loaded_progress(load_context: Dictionary) -> void:
	var loaded_progress: Dictionary = _read_progress_dictionary(save_data.get("progress", {}))
	_debug_log_streak_checkpoint(
		"after_load_save_data",
		{
			"loaded_from": str(load_context.get("loaded_from", "default")),
			"recovered_from": str(load_context.get("recovered_from", "")),
			"needs_write": bool(load_context.get("needs_write", false)),
			"rewrite_reason": str(load_context.get("rewrite_reason", "")),
			"loaded_save_streak": _debug_extract_streak_state_from_progress(loaded_progress)
		}
	)
	_import_progress_into_runtime(
		loaded_progress,
		"before_global_import_progress",
		"after_global_import_progress",
		{"loaded_from": str(load_context.get("loaded_from", "default"))}
	)


func _read_save_from_disk() -> Dictionary:
	var load_result: Dictionary = _storage_helper.load_available_save_data(
		SAVE_PATH,
		TEMP_SAVE_PATH,
		BACKUP_SAVE_PATH
	)
	var load_context: Dictionary = _default_load_context()
	if not bool(load_result.get("ok", false)):
		load_context["needs_write"] = true
		return load_context

	var raw_data: Dictionary = load_result.get("data", {})
	load_context["save_data"] = _schema_helper.normalize_save_data(
		raw_data,
		_resume_helper.default_resume_state()
	)
	load_context["loaded_from"] = str(load_result.get("source", "primary"))
	if str(load_context.get("loaded_from", "primary")) != "primary":
		load_context["recovered_from"] = str(load_context.get("loaded_from", ""))
		load_context["needs_write"] = true
	load_context["rewrite_reason"] = _schema_helper.rewrite_reason(raw_data)
	if not str(load_context.get("rewrite_reason", "")).is_empty():
		load_context["needs_write"] = true
	return load_context


func _default_load_context() -> Dictionary:
	return {
		"save_data": _default_save_data(),
		"loaded_from": "default",
		"recovered_from": "",
		"needs_write": false,
		"rewrite_reason": ""
	}


func _default_save_data() -> Dictionary:
	return _schema_helper.build_default_save_data(_resume_helper.default_resume_state())


func _ensure_local_save_structure() -> bool:
	var profile_result: Dictionary = _normalize_profile_for_save_data()
	save_data["profile"] = profile_result.get("profile", {})

	var changed: bool = bool(profile_result.get("changed", false))
	if _ensure_progress_and_history_shape():
		changed = true
	if _ensure_save_meta_shape():
		changed = true
	if _ensure_resume_state_shape():
		changed = true

	if changed:
		_mark_save_dirty()
	return changed


func _normalize_profile_for_save_data() -> Dictionary:
	var changed := false
	var stored_profile: Variant = save_data.get("profile", {})
	if not stored_profile is Dictionary:
		stored_profile = {}
		changed = true

	var profile: Dictionary = _schema_helper.normalize_profile_data(stored_profile)
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

	return {
		"profile": profile,
		"changed": changed
	}


func _ensure_progress_and_history_shape() -> bool:
	var changed := false
	if not save_data.get("progress", {}) is Dictionary:
		save_data["progress"] = {}
		changed = true
	if not save_data.get("history", []) is Array:
		save_data["history"] = []
		changed = true
	return changed


func _ensure_save_meta_shape() -> bool:
	var stored_save_meta: Variant = save_data.get("save_meta", {})
	var changed: bool = not stored_save_meta is Dictionary
	save_data["save_meta"] = _schema_helper.normalize_save_meta(stored_save_meta)
	return changed


func _ensure_resume_state_shape() -> bool:
	var stored_resume_state: Variant = save_data.get("resume_state", {})
	if not stored_resume_state is Dictionary:
		save_data["resume_state"] = _resume_helper.default_resume_state()
		return true

	save_data["resume_state"] = _resume_helper.normalize_resume_state(stored_resume_state)
	return false


func _rewrite_repaired_save_data(
	loaded_from: String,
	recovered_from: String,
	rewrite_reason: String = ""
) -> void:
	runtime_save_status["last_loaded_from"] = loaded_from
	runtime_save_status["recovered_from"] = recovered_from

	var effective_reason: String = (
		rewrite_reason if not rewrite_reason.is_empty() else "load_repair"
	)
	if _write_save_to_disk(true, effective_reason):
		_emit_status_after_repaired_load(loaded_from, recovered_from)
		return

	_emit_load_repair_write_error(loaded_from, recovered_from)


func _emit_status_after_repaired_load(loaded_from: String, recovered_from: String) -> void:
	if recovered_from.is_empty():
		_emit_save_status(
			"ready",
			str(runtime_save_status.get("last_loaded_from", "primary"))
		)
		return
	_emit_save_status(
		"recovered",
		str(runtime_save_status.get("last_loaded_from", loaded_from)),
		recovered_from
	)


func _emit_load_repair_write_error(loaded_from: String, recovered_from: String) -> void:
	if not recovered_from.is_empty() and FileAccess.file_exists(TEMP_SAVE_PATH):
		has_unsaved_changes = false
		_emit_save_status("recovered", loaded_from, recovered_from)
		return
	_emit_save_status(
		"error",
		loaded_from,
		recovered_from,
		"No se pudo restaurar el save principal en disco."
	)


func _write_save_to_disk(force: bool = false, reason: String = "save") -> bool:
	if not force and not has_unsaved_changes:
		return true

	_update_save_meta_for_write(reason)
	var serialized_payload: String = _storage_helper.serialize_save_data(save_data.duplicate(true))
	_debug_log_streak_checkpoint(
		"before_write_to_disk",
		{
			"reason": reason,
			"disk_context_before_write": _debug_read_disk_streak_context()
		}
	)
	if not _write_temp_snapshot(serialized_payload):
		return false
	if not _backup_primary_save_if_needed():
		return false

	var replace_result: Dictionary = _replace_primary_save_with_temp()
	if not bool(replace_result.get("ok", false)):
		return false

	_finish_successful_save_write(replace_result, reason)
	return true


func _update_save_meta_for_write(reason: String) -> void:
	var save_meta: Dictionary = _current_save_meta()
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = int(save_meta.get("write_count", 0)) + 1
	save_data["save_meta"] = save_meta


func _finish_successful_save_write(replace_result: Dictionary, reason: String) -> void:
	if bool(replace_result.get("wrote_primary", false)):
		runtime_save_status["last_loaded_from"] = "primary"
		runtime_save_status["recovered_from"] = ""

	has_unsaved_changes = false
	_debug_log_streak_checkpoint(
		"after_write_to_disk",
		{
			"reason": reason,
			"disk_context_after_write": _debug_read_disk_streak_context()
		}
	)
	_emit_save_status(
		"saved",
		str(runtime_save_status.get("last_loaded_from", "default")),
		str(runtime_save_status.get("recovered_from", ""))
	)


func _write_temp_snapshot(serialized_payload: String) -> bool:
	var temp_file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if temp_file == null:
		_publish_write_error("No se pudo abrir el archivo temporal del save.")
		return false
	temp_file.store_string(serialized_payload)
	temp_file.flush()
	temp_file = null
	return true


func _backup_primary_save_if_needed() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	if str(runtime_save_status.get("last_loaded_from", "primary")) != "primary":
		return true
	if _storage_helper.copy_file(SAVE_PATH, BACKUP_SAVE_PATH):
		return true
	_publish_write_error("No se pudo generar el backup del save local.")
	return false


func _replace_primary_save_with_temp() -> Dictionary:
	_storage_helper.remove_file_if_exists(SAVE_PATH)
	if _storage_helper.move_file(TEMP_SAVE_PATH, SAVE_PATH) == OK:
		return {"ok": true, "wrote_primary": true}

	if FileAccess.file_exists(TEMP_SAVE_PATH):
		var loaded_from: String = str(runtime_save_status.get("last_loaded_from", "primary"))
		if loaded_from != "primary":
			return {"ok": true, "wrote_primary": false}

	if FileAccess.file_exists(BACKUP_SAVE_PATH):
		_storage_helper.copy_file(BACKUP_SAVE_PATH, SAVE_PATH)

	_publish_write_error("No se pudo reemplazar el save principal.")
	return {"ok": false, "wrote_primary": false}


func _build_clean_profile_update(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return {
		"username": username.strip_edges(),
		"age": max(0, age),
		"email": email.strip_edges(),
		"avatar_path": avatar_source_path.strip_edges()
	}


func _apply_profile_identity_changes(profile: Dictionary, clean_profile_update: Dictionary) -> void:
	var clean_username: String = str(clean_profile_update.get("username", ""))
	profile["username"] = DEFAULT_PROFILE_NAME if clean_username.is_empty() else clean_username
	profile["age"] = int(clean_profile_update.get("age", 0))
	profile["email"] = str(clean_profile_update.get("email", ""))


func _apply_profile_avatar_change(
	profile: Dictionary,
	clean_avatar_path: String,
	previous_avatar_path: String
) -> Dictionary:
	if clean_avatar_path.is_empty():
		_profile_helper.remove_managed_avatar(AVATARS_DIR, previous_avatar_path)
		profile["avatar_path"] = ""
		return {"ok": true}

	var persisted_avatar_path: String = _profile_helper.persist_avatar(
		AVATARS_DIR,
		LOCAL_PROFILE_KEY,
		clean_avatar_path
	)
	if persisted_avatar_path.is_empty():
		return {
			"ok": false,
			"message": "No se pudo copiar la foto seleccionada al almacenamiento local."
		}

	if persisted_avatar_path != previous_avatar_path:
		_profile_helper.remove_managed_avatar(AVATARS_DIR, previous_avatar_path)
	profile["avatar_path"] = persisted_avatar_path
	return {"ok": true}


func _stamp_profile_timestamps(profile: Dictionary) -> void:
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	profile["updated_at"] = timestamp
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = timestamp


func _persist_updated_profile() -> Dictionary:
	_append_history("Perfil local actualizado", {"type": "profile_updated"})
	sync_runtime_progress_to_current_save()
	if not _write_save_to_disk(false, "profile_updated"):
		return {
			"ok": false,
			"message": "No se pudo escribir el perfil local en disco."
		}

	var updated_profile: Dictionary = get_current_user_profile()
	user_registered.emit(updated_profile)
	user_logged_in.emit(updated_profile)
	progress_loaded.emit(updated_profile)
	return {
		"ok": true,
		"message": "Perfil local actualizado.",
		"profile": updated_profile
	}


func _snapshot_runtime_progress_into_save_data() -> void:
	_debug_log_streak_checkpoint("before_sync_runtime_to_save")
	save_data["profile"] = get_current_user_profile()
	save_data["progress"] = Global.export_progress()
	_debug_log_streak_checkpoint("after_sync_runtime_to_save")


func _write_current_save_and_emit_progress_saved(reason: String) -> bool:
	if not _write_save_to_disk(false, reason):
		return false
	progress_saved.emit(get_current_user_profile())
	return true


func _build_manual_save_history_metadata(resume_state: Dictionary) -> Dictionary:
	return {
		"type": "manual_save",
		"context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
		"track": str(resume_state.get("track_key", "")),
		"level": int(resume_state.get("level_number", Global.current_level))
	}


func _current_save_meta() -> Dictionary:
	return _schema_helper.normalize_save_meta(save_data.get("save_meta", {}))


func _build_save_status_snapshot(
	save_meta: Dictionary,
	local_save_summary: Dictionary,
	available_save_count: int
) -> Dictionary:
	return {
		"state": str(runtime_save_status.get("state", "idle")),
		"last_saved_at": str(save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(save_meta.get("last_saved_reason", "")),
		"write_count": int(save_meta.get("write_count", 0)),
		"last_loaded_from": str(runtime_save_status.get("last_loaded_from", "default")),
		"recovered_from": str(runtime_save_status.get("recovered_from", "")),
		"last_error": str(runtime_save_status.get("last_error", "")),
		"has_unsaved_changes": has_unsaved_changes,
		"save_id": str(local_save_summary.get("id", "")),
		"save_title": str(local_save_summary.get("title", "")),
		"save_count": available_save_count,
		"session_id": str(local_save_summary.get("id", "")),
		"session_title": str(local_save_summary.get("title", "")),
		"session_count": available_save_count
	}


func _build_current_save_summary(
	profile: Dictionary,
	save_meta: Dictionary,
	resume_state: Dictionary,
	progress_summary: Dictionary
) -> Dictionary:
	return {
		"id": LOCAL_SAVE_ID,
		"title": LOCAL_SAVE_TITLE,
		"created_at": str(profile.get("created_at", "")),
		"updated_at": _resolve_current_save_updated_at(profile, save_meta),
		"resume_hint": _resume_helper.format_resume_hint_from_state(resume_state),
		"resume_context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume_state.get("track_key", "")),
		"resume_level_number": int(resume_state.get("level_number", 1)),
		"progress_summary": progress_summary,
		"can_resume": true,
		"is_active": true
	}


func _resolve_current_save_updated_at(profile: Dictionary, save_meta: Dictionary) -> String:
	var updated_at: String = str(save_meta.get("last_saved_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("updated_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("created_at", ""))
	return updated_at


func _build_level_completed_history_message(track_key: String, level_number: int) -> String:
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track_key)
	var track_label: String = str(track_definition.get("label", track_key)).strip_edges()
	return "Completaste %s - capitulo %d" % [
		track_label if not track_label.is_empty() else track_key,
		level_number
	]


func _record_level_completed_streak(track_key: String, level_number: int) -> Dictionary:
	var updated_streak_state: Dictionary = Global.record_streak_activity(
		"level_completed",
		{
			"track_key": track_key,
			"level_number": level_number
		}
	)
	_debug_log_streak_checkpoint(
		"after_valid_activity_level_completed",
		{
			"activity_type": "level_completed",
			"track_key": track_key,
			"level_number": level_number,
			"runtime_streak_after_activity": updated_streak_state
		}
	)
	return updated_streak_state


func _build_question_session_history_message(question_count: int, score: int) -> String:
	return "Sesion de preguntas completada (%d/%d)" % [score, question_count]


func _record_question_session_streak(question_count: int, score: int) -> Dictionary:
	var updated_streak_state: Dictionary = Global.record_streak_activity(
		"question_session_completed",
		{
			"question_count": question_count,
			"score": score
		}
	)
	_debug_log_streak_checkpoint(
		"after_valid_activity_question_session_completed",
		{
			"activity_type": "question_session_completed",
			"question_count": question_count,
			"score": score,
			"runtime_streak_after_activity": updated_streak_state
		}
	)
	return updated_streak_state


func _import_progress_into_runtime(
	loaded_progress: Dictionary,
	before_checkpoint: String,
	after_checkpoint: String,
	metadata: Dictionary = {}
) -> void:
	var before_metadata: Dictionary = metadata.duplicate(true)
	before_metadata["loaded_save_streak"] = _debug_extract_streak_state_from_progress(
		loaded_progress
	)
	_debug_log_streak_checkpoint(before_checkpoint, before_metadata)

	Global.import_progress(loaded_progress)

	var after_metadata: Dictionary = metadata.duplicate(true)
	after_metadata["loaded_save_streak"] = _debug_extract_streak_state_from_progress(
		loaded_progress
	)
	after_metadata["runtime_streak_after_import"] = Global.get_streak_state()
	_debug_log_streak_checkpoint(after_checkpoint, after_metadata)


func _append_history(message: String, metadata: Dictionary = {}) -> void:
	_resume_helper.append_history(save_data, message, metadata)
	_mark_save_dirty()


func _store_resume_state(raw_resume_state: Dictionary) -> void:
	if _resume_helper.store_resume_state(save_data, raw_resume_state):
		_mark_save_dirty()


func _reset_current_save_data(profile: Dictionary) -> void:
	Global.reset_progress()
	save_data["profile"] = profile
	save_data["progress"] = Global.export_progress()
	save_data["history"] = []
	save_data["resume_state"] = _resume_helper.default_resume_state()
	save_data["save_meta"] = _schema_helper.default_save_meta()
	_mark_save_dirty()


func _apply_resume_level_to_global_state(resume_state: Dictionary) -> Dictionary:
	var resume_track_key: String = str(resume_state.get("track_key", ""))
	Global.current_level = clampi(
		int(resume_state.get("level_number", Global.current_level)),
		1,
		Global.get_track_level_count(resume_track_key)
	)
	return resume_state


func _emit_progress_refresh_signals() -> void:
	var current_profile: Dictionary = get_current_user_profile()
	progress_loaded.emit(current_profile)
	progress_saved.emit(current_profile)


func _build_streak_feedback(
	previous_streak_state: Dictionary,
	updated_streak_state: Dictionary
) -> Dictionary:
	var streak_feedback: Dictionary = {"should_show": false}
	var today_day_key: String = Time.get_date_string_from_system(false)
	var previous_activity_day: String = str(
		previous_streak_state.get("last_activity_day", "")
	).strip_edges()
	var updated_activity_day: String = str(
		updated_streak_state.get("last_activity_day", "")
	).strip_edges()
	if previous_activity_day == today_day_key or updated_activity_day != today_day_key:
		return streak_feedback

	var current_count: int = int(updated_streak_state.get("current_count", 0))
	if current_count <= 1:
		return {
			"should_show": true,
			"feedback_key": "activated",
			"title": "Racha activada",
			"message": "Hoy empezaste una racha de 1 dia.",
			"current_count": 1,
			"best_count": int(updated_streak_state.get("best_count", 0))
		}
	return {
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


func _publish_write_error(message: String) -> void:
	_debug_log_streak_checkpoint(
		"write_error",
		{
			"last_error": message,
			"disk_context_on_error": _debug_read_disk_streak_context()
		}
	)
	_emit_save_status(
		"error",
		str(runtime_save_status.get("last_loaded_from", "default")),
		str(runtime_save_status.get("recovered_from", "")),
		message
	)


func _mark_save_dirty() -> void:
	if has_unsaved_changes:
		return
	has_unsaved_changes = true
	_emit_save_status(
		"dirty",
		str(runtime_save_status.get("last_loaded_from", "default")),
		str(runtime_save_status.get("recovered_from", ""))
	)


func _emit_save_status(
	state: String,
	loaded_from: String = "",
	recovered_from: String = "",
	last_error: String = ""
) -> void:
	runtime_save_status["state"] = state
	if not loaded_from.is_empty():
		runtime_save_status["last_loaded_from"] = loaded_from
	runtime_save_status["recovered_from"] = recovered_from
	runtime_save_status["last_error"] = last_error
	notify_save_status_changed()


func _read_progress_dictionary(raw_progress: Variant) -> Dictionary:
	return raw_progress if raw_progress is Dictionary else {}


func _debug_extract_streak_state_from_progress(progress_snapshot: Variant) -> Dictionary:
	if not progress_snapshot is Dictionary:
		return {}

	var progress_data: Dictionary = progress_snapshot
	var raw_progress_system_states: Variant = progress_data.get(
		"progress_system_states",
		{}
	)
	if not raw_progress_system_states is Dictionary:
		return {}

	var progress_system_states: Dictionary = raw_progress_system_states
	var raw_streak_state: Variant = progress_system_states.get("streak", {})
	if not raw_streak_state is Dictionary:
		return {}
	return (raw_streak_state as Dictionary).duplicate(true)


func _debug_read_disk_streak_context() -> Dictionary:
	if not OS.is_debug_build():
		return {}

	var load_result: Dictionary = _storage_helper.load_available_save_data(
		SAVE_PATH,
		TEMP_SAVE_PATH,
		BACKUP_SAVE_PATH
	)
	if not bool(load_result.get("ok", false)):
		return {
			"source": "missing",
			"streak": {}
		}

	var raw_data: Variant = load_result.get("data", {})
	var persisted_save_data: Dictionary = raw_data if raw_data is Dictionary else {}
	return {
		"source": str(load_result.get("source", "default")),
		"streak": _debug_extract_streak_state_from_progress(
			persisted_save_data.get("progress", {})
		)
	}


func _debug_log_streak_checkpoint(checkpoint: String, metadata: Dictionary = {}) -> void:
	if not OS.is_debug_build():
		return

	var payload: Dictionary = {
		"checkpoint": checkpoint,
		"runtime_streak": Global.get_streak_state(),
		"runtime_export_streak": _debug_extract_streak_state_from_progress(
			Global.export_progress()
		),
		"save_data_streak": _debug_extract_streak_state_from_progress(
			save_data.get("progress", {})
		),
		"save_runtime_status": {
			"state": str(runtime_save_status.get("state", "idle")),
			"last_loaded_from": str(runtime_save_status.get("last_loaded_from", "default")),
			"recovered_from": str(runtime_save_status.get("recovered_from", "")),
			"last_error": str(runtime_save_status.get("last_error", "")),
			"has_unsaved_changes": has_unsaved_changes
		}
	}
	for raw_key in metadata.keys():
		payload[str(raw_key)] = metadata[raw_key]

	print("%s %s" % [DEBUG_STREAK_LOG_PREFIX, JSON.stringify(payload)])