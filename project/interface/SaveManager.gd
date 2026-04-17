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
	var load_context: Dictionary = _read_save_from_disk()
	save_data = load_context.get("save_data", _default_save_data())

	var loaded_from: String = str(load_context.get("loaded_from", "default"))
	var recovered_from: String = str(load_context.get("recovered_from", ""))
	var rewrite_reason: String = str(load_context.get("rewrite_reason", ""))
	var needs_write: bool = bool(load_context.get("needs_write", false))

	if _ensure_local_profile():
		needs_write = true
	if _resume_helper.repair_resume_state(save_data):
		_mark_save_dirty()
		needs_write = true

	if needs_write:
		_finish_load_with_repair(loaded_from, recovered_from, rewrite_reason)
	else:
		has_unsaved_changes = false
		_emit_save_status("ready", loaded_from)

	Global.import_progress(save_data.get("progress", {}))


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

	var clean_username: String = username.strip_edges()
	var clean_email: String = email.strip_edges()
	var clean_avatar_path: String = avatar_source_path.strip_edges()
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	var profile: Dictionary = get_current_user_profile()
	var previous_avatar_path: String = str(profile.get("avatar_path", "")).strip_edges()

	profile["username"] = DEFAULT_PROFILE_NAME if clean_username.is_empty() else clean_username
	profile["age"] = max(0, age)
	profile["email"] = clean_email
	if clean_avatar_path.is_empty():
		_profile_helper.remove_managed_avatar(AVATARS_DIR, previous_avatar_path)
		profile["avatar_path"] = ""
	else:
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

	profile["updated_at"] = timestamp
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = timestamp

	save_data["profile"] = profile
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
	save_data["profile"] = get_current_user_profile()
	save_data["progress"] = Global.export_progress()
	_mark_save_dirty()


func persist_runtime_progress_to_current_save() -> void:
	sync_runtime_progress_to_current_save()
	if _write_save_to_disk(false, "progress_sync"):
		progress_saved.emit(get_current_user_profile())


func sync_runtime_progress_from_current_save() -> void:
	Global.import_progress(save_data.get("progress", {}))


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
	var resume_state: Dictionary = get_resume_state()
	_append_history(
		"Guardado manual",
		{
			"type": "manual_save",
			"context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
			"track": str(resume_state.get("track_key", "")),
			"level": int(resume_state.get("level_number", Global.current_level))
		}
	)
	if _write_save_to_disk(false, "manual_save"):
		progress_saved.emit(get_current_user_profile())


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

	var updated_streak_state: Dictionary = Global.record_streak_activity(
		"level_completed",
		{
			"track_key": track_key,
			"level_number": level_number
		}
	)
	var streak_feedback: Dictionary = _build_streak_feedback(
		previous_streak_state,
		updated_streak_state
	)

	sync_runtime_progress_to_current_save()
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track_key)
	var track_label: String = str(track_definition.get("label", track_key)).strip_edges()
	_append_history(
		"Completaste %s - capitulo %d" % [
			track_label if not track_label.is_empty() else track_key,
			level_number
		],
		{
			"type": "level_completed",
			"track": track_key,
			"level": level_number
		}
	)
	if _write_save_to_disk(false, "level_completed"):
		progress_saved.emit(get_current_user_profile())
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
	sync_runtime_progress_to_current_save()
	_append_history(
		"Sesion de preguntas completada (%d/%d)" % [score, question_count],
		{
			"type": "question_session_completed",
			"question_count": question_count,
			"score": score
		}
	)
	if _write_save_to_disk(false, "question_session_completed"):
		progress_saved.emit(get_current_user_profile())


func get_save_status() -> Dictionary:
	var save_meta: Dictionary = _schema_helper.normalize_save_meta(save_data.get("save_meta", {}))
	var local_save_summary: Dictionary = get_current_save_summary()
	var available_save_count: int = list_available_saves(true).size()
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


func notify_save_status_changed() -> void:
	save_status_changed.emit(get_save_status())


func get_current_save_id() -> String:
	return LOCAL_SAVE_ID if can_resume_current_save() else ""


func get_current_save_summary() -> Dictionary:
	if not can_resume_current_save():
		return {}

	var resume_state: Dictionary = get_resume_state()
	var progress_summary: Dictionary = summarize_progress_data(save_data.get("progress", {}))
	var profile: Dictionary = get_current_user_profile()
	var save_meta: Dictionary = _schema_helper.normalize_save_meta(save_data.get("save_meta", {}))
	var updated_at: String = str(save_meta.get("last_saved_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("updated_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("created_at", ""))

	return {
		"id": LOCAL_SAVE_ID,
		"title": LOCAL_SAVE_TITLE,
		"created_at": str(profile.get("created_at", "")),
		"updated_at": updated_at,
		"resume_hint": _resume_helper.format_resume_hint_from_state(resume_state),
		"resume_context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume_state.get("track_key", "")),
		"resume_level_number": int(resume_state.get("level_number", 1)),
		"progress_summary": progress_summary,
		"can_resume": true,
		"is_active": true
	}


func list_available_saves(include_empty: bool = false) -> Array:
	var save_summary: Dictionary = get_current_save_summary()
	if save_summary.is_empty():
		return []
	if include_empty or bool(save_summary.get("can_resume", false)):
		return [save_summary]
	return []


func _read_save_from_disk() -> Dictionary:
	var load_result: Dictionary = _storage_helper.load_available_save_data(
		SAVE_PATH,
		TEMP_SAVE_PATH,
		BACKUP_SAVE_PATH
	)
	var load_context: Dictionary = {
		"save_data": _default_save_data(),
		"loaded_from": "default",
		"recovered_from": "",
		"needs_write": false,
		"rewrite_reason": ""
	}
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


func _default_save_data() -> Dictionary:
	return _schema_helper.build_default_save_data(_resume_helper.default_resume_state())


func _ensure_local_profile() -> bool:
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

	if not save_data.get("progress", {}) is Dictionary:
		save_data["progress"] = {}
		changed = true

	if not save_data.get("history", []) is Array:
		save_data["history"] = []
		changed = true

	var stored_save_meta: Variant = save_data.get("save_meta", {})
	if not stored_save_meta is Dictionary:
		changed = true
	save_data["save_meta"] = _schema_helper.normalize_save_meta(stored_save_meta)

	var stored_resume_state: Variant = save_data.get("resume_state", {})
	if not stored_resume_state is Dictionary:
		changed = true
		save_data["resume_state"] = _resume_helper.default_resume_state()
	else:
		save_data["resume_state"] = _resume_helper.normalize_resume_state(
			stored_resume_state
		)

	save_data["profile"] = profile
	if changed:
		_mark_save_dirty()
	return changed


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


func _finish_load_with_repair(
	loaded_from: String,
	recovered_from: String,
	rewrite_reason: String = ""
) -> void:
	runtime_save_status["last_loaded_from"] = loaded_from
	runtime_save_status["recovered_from"] = recovered_from

	var effective_reason: String = rewrite_reason
	if effective_reason.is_empty():
		effective_reason = "load_repair"

	if not _write_save_to_disk(true, effective_reason):
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
		return

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


func _write_save_to_disk(force: bool = false, reason: String = "save") -> bool:
	if not force and not has_unsaved_changes:
		return true

	var save_meta: Dictionary = _schema_helper.normalize_save_meta(save_data.get("save_meta", {}))
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = int(save_meta.get("write_count", 0)) + 1
	save_data["save_meta"] = save_meta

	var payload: Dictionary = save_data.duplicate(true)
	var serialized_payload: String = _storage_helper.serialize_save_data(payload)
	if not _write_temp_snapshot(serialized_payload):
		return false
	if not _backup_primary_save_if_needed():
		return false

	var replace_result: Dictionary = _replace_primary_save_with_temp()
	if not bool(replace_result.get("ok", false)):
		return false

	if bool(replace_result.get("wrote_primary", false)):
		runtime_save_status["last_loaded_from"] = "primary"
		runtime_save_status["recovered_from"] = ""

	has_unsaved_changes = false
	_emit_save_status(
		"saved",
		str(runtime_save_status.get("last_loaded_from", "default")),
		str(runtime_save_status.get("recovered_from", ""))
	)
	return true


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


func _publish_write_error(message: String) -> void:
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