extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveLocalResumeHelperScript := preload(
	"res://interface/save_local/SaveLocalResumeHelper.gd"
)
const SaveLocalStorageHelperScript := preload(
	"res://interface/save_local/persistence/SaveLocalStorageHelper.gd"
)
const SaveDiskWriterScript := preload(
	"res://interface/save_local/SaveDiskWriter.gd"
)
const SaveLoadPipelineScript := preload(
	"res://interface/save_local/SaveLoadPipeline.gd"
)

@warning_ignore("unused_signal")
signal user_registered(profile: Dictionary)
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
var _resume_helper: RefCounted
var _storage_helper: RefCounted
var _disk_writer: RefCounted
var _load_pipeline: RefCounted


func _init() -> void:
	_profile_helper = SaveLocalProfileHelperScript.new()
	_resume_helper = SaveLocalResumeHelperScript.new(
		ARCHIVERO_SCENE,
		RESUME_CONTEXT_HUB,
		RESUME_CONTEXT_BOOK,
		RESUME_CONTEXT_LEVEL,
		HISTORY_LIMIT,
		GAMEPLAY_HISTORY_TYPES
	)
	_storage_helper = SaveLocalStorageHelperScript.new()
	_disk_writer = SaveDiskWriterScript.new(
		_storage_helper,
		SAVE_PATH,
		TEMP_SAVE_PATH,
		BACKUP_SAVE_PATH
	)
	_load_pipeline = SaveLoadPipelineScript.new(
		_storage_helper,
		_profile_helper,
		_resume_helper,
		SAVE_PATH,
		TEMP_SAVE_PATH,
		BACKUP_SAVE_PATH,
		SAVE_VERSION,
		DEFAULT_PROFILE_NAME
	)


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress_to_disk()


func load_data() -> void:
	var load_result: Dictionary = _load_pipeline.load_from_disk()
	save_data = load_result.get("save_data", _load_pipeline.default_save_data())

	var needs_write: bool = bool(load_result.get("needs_write", false))
	if _load_pipeline.repair_structure(save_data):
		_mark_save_dirty()
		needs_write = true
	if _resume_helper.repair_resume_state(save_data):
		_mark_save_dirty()
		needs_write = true

	var loaded_from: String = str(load_result.get("loaded_from", "default"))
	var recovered_from: String = str(load_result.get("recovered_from", ""))
	var rewrite_reason: String = str(load_result.get("rewrite_reason", ""))

	if needs_write:
		_write_after_load_repair(loaded_from, recovered_from, rewrite_reason)
	else:
		has_unsaved_changes = false
		_emit_save_status("ready", loaded_from)

	var raw_progress: Variant = save_data.get("progress", {})
	Global.import_progress(raw_progress if raw_progress is Dictionary else {})
	progress_loaded.emit(get_current_user_profile())


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

	var profile: Dictionary = get_current_user_profile()
	var previous_avatar_path: String = str(profile.get("avatar_path", "")).strip_edges()
	var avatar_result: Dictionary = _profile_helper.apply_avatar_change(
		profile,
		avatar_source_path.strip_edges(),
		previous_avatar_path,
		AVATARS_DIR,
		LOCAL_PROFILE_KEY
	)
	if not bool(avatar_result.get("ok", false)):
		return avatar_result

	_profile_helper.apply_identity_changes(profile, username, age, email, DEFAULT_PROFILE_NAME)
	_profile_helper.stamp_timestamps(profile)
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

	var normalized_profile: Dictionary = _profile_helper.normalize_profile_data(stored_profile, DEFAULT_PROFILE_NAME)
	if str(normalized_profile.get("username", "")).is_empty():
		normalized_profile["username"] = DEFAULT_PROFILE_NAME
	return normalized_profile


func _capture_progress_snapshot() -> void:
	save_data["profile"] = get_current_user_profile()
	save_data["progress"] = Global.export_progress()
	_mark_save_dirty()


func save_progress_to_disk() -> void:
	_capture_progress_snapshot()
	_write_current_save_and_emit_progress_saved("progress_sync")


func reload_from_disk_and_get_resume() -> Dictionary:
	load_data()
	var raw_progress: Variant = save_data.get("progress", {})
	Global.import_progress(raw_progress if raw_progress is Dictionary else {})
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


func _summarize_progress_data(progress: Variant) -> Dictionary:
	var progress_data: Dictionary = progress if progress is Dictionary else {}
	var summary: Dictionary = {
		"total": 0,
		"max_total": 0
	}
	for raw_track_key in GameTrackCatalog.get_track_keys():
		var track_key: String = str(raw_track_key)
		var completed_levels: int = _count_completed_levels(
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
	_capture_progress_snapshot()
	var resume: Dictionary = get_resume_state()
	_append_history("Guardado manual", {
		"type": "manual_save",
		"context": str(resume.get("context", RESUME_CONTEXT_HUB)),
		"track": str(resume.get("track_key", "")),
		"level": int(resume.get("level_number", Global.current_level))
	})
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


func get_resume_state() -> Dictionary:
	return _resume_helper.get_resume_state(save_data)


func get_current_resume_hint() -> String:
	return _resume_helper.format_resume_hint_from_state(get_resume_state())


func can_resume_current_save() -> bool:
	var saved_progress_summary: Dictionary = _summarize_progress_data(save_data.get("progress", {}))
	if int(saved_progress_summary.get("total", 0)) > 0:
		return true

	var resume_context: String = str(get_resume_state().get("context", RESUME_CONTEXT_HUB))
	if resume_context != RESUME_CONTEXT_HUB:
		return true

	return _resume_helper.history_has_gameplay_progress(save_data.get("history", []))


func record_level_completed(track_key: String, level_number: int) -> void:
	Global.clear_partial_level_state(track_key, level_number)

	# Resume: siguiente nivel o reset
	if level_number < Global.get_track_level_count(track_key):
		set_resume_to_level(track_key, level_number + 1)
	else:
		_store_resume_state(_resume_helper.default_resume_state())

	_capture_progress_snapshot()
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track_key)
	var track_label: String = str(track_definition.get("label", track_key)).strip_edges()
	_append_history(
		"Completaste %s - capitulo %d" % [
			track_label if not track_label.is_empty() else track_key,
			level_number
		],
		{"type": "level_completed", "track": track_key, "level": level_number}
	)
	_write_current_save_and_emit_progress_saved("level_completed")


func record_question_session_completed(question_count: int, score: int) -> void:
	if question_count < 1:
		return

	Global.record_streak_activity("question_session_completed", {"question_count": question_count, "score": score})
	_capture_progress_snapshot()
	_append_history(
		"Sesion de preguntas completada (%d/%d)" % [score, question_count],
		{"type": "question_session_completed", "question_count": question_count, "score": score}
	)
	_write_current_save_and_emit_progress_saved("question_session_completed")


func get_save_status() -> Dictionary:
	var raw_meta: Variant = save_data.get("save_meta", {})
	var meta: Dictionary = raw_meta if raw_meta is Dictionary else {}
	var save_summary: Dictionary = get_current_save_summary()
	return {
		"state": str(runtime_save_status.get("state", "idle")),
		"last_saved_at": str(meta.get("last_saved_at", "")),
		"last_saved_reason": str(meta.get("last_saved_reason", "")),
		"write_count": max(0, int(meta.get("write_count", 0))),
		"last_loaded_from": str(runtime_save_status.get("last_loaded_from", "default")),
		"recovered_from": str(runtime_save_status.get("recovered_from", "")),
		"last_error": str(runtime_save_status.get("last_error", "")),
		"has_unsaved_changes": has_unsaved_changes,
		"save_id": str(save_summary.get("id", "")),
		"save_title": str(save_summary.get("title", "")),
		"save_count": 1 if not save_summary.is_empty() else 0
	}


func get_current_save_summary() -> Dictionary:
	if not can_resume_current_save():
		return {}

	var profile: Dictionary = get_current_user_profile()
	var raw_meta: Variant = save_data.get("save_meta", {})
	var meta: Dictionary = raw_meta if raw_meta is Dictionary else {}
	var resume: Dictionary = get_resume_state()
	var progress: Dictionary = _summarize_progress_data(save_data.get("progress", {}))

	var updated_at: String = str(meta.get("last_saved_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("updated_at", ""))
	if updated_at.is_empty():
		updated_at = str(profile.get("created_at", ""))

	return {
		"id": LOCAL_SAVE_ID,
		"title": LOCAL_SAVE_TITLE,
		"created_at": str(profile.get("created_at", "")),
		"updated_at": updated_at,
		"resume_hint": _resume_helper.format_resume_hint_from_state(resume),
		"resume_context": str(resume.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume.get("track_key", "")),
		"resume_level_number": int(resume.get("level_number", 1)),
		"progress_summary": progress,
		"can_resume": true,
		"is_active": true
	}


# Escribe a disco después de reparar el save durante la carga.
# Unifica la lógica que antes estaba en _rewrite_repaired_save_data,
# _emit_status_after_repaired_load y _emit_load_repair_write_error.
func _write_after_load_repair(
	loaded_from: String,
	recovered_from: String,
	reason: String
) -> void:
	runtime_save_status["last_loaded_from"] = loaded_from
	runtime_save_status["recovered_from"] = recovered_from
	var effective_reason: String = reason if not reason.is_empty() else "load_repair"

	if not _write_save_to_disk(true, effective_reason):
		if not recovered_from.is_empty() and FileAccess.file_exists(TEMP_SAVE_PATH):
			has_unsaved_changes = false
			_emit_save_status("recovered", loaded_from, recovered_from)
		else:
			_emit_save_status(
				"error", loaded_from, recovered_from,
				"No se pudo restaurar el save principal en disco."
			)
		return

	if recovered_from.is_empty():
		_emit_save_status("ready", str(runtime_save_status.get("last_loaded_from", "primary")))
	else:
		_emit_save_status(
			"recovered",
			str(runtime_save_status.get("last_loaded_from", loaded_from)),
			recovered_from
		)


func _write_save_to_disk(force: bool = false, reason: String = "save") -> bool:
	if not force and not has_unsaved_changes:
		return true

	var result: Dictionary = _disk_writer.write(save_data, runtime_save_status, reason)
	if not bool(result.get("ok", false)):
		_emit_save_status(
			"error",
			str(runtime_save_status.get("last_loaded_from", "default")),
			str(runtime_save_status.get("recovered_from", "")),
			str(result.get("error_message", ""))
		)
		return false

	if bool(result.get("wrote_primary", false)):
		runtime_save_status["last_loaded_from"] = "primary"
		runtime_save_status["recovered_from"] = ""

	has_unsaved_changes = false
	_emit_save_status(
		"saved",
		str(runtime_save_status.get("last_loaded_from", "default")),
		str(runtime_save_status.get("recovered_from", ""))
	)
	return true


func _persist_updated_profile() -> Dictionary:
	_append_history("Perfil local actualizado", {"type": "profile_updated"})
	_capture_progress_snapshot()
	if not _write_save_to_disk(false, "profile_updated"):
		return {
			"ok": false,
			"message": "No se pudo escribir el perfil local en disco."
		}

	var updated_profile: Dictionary = get_current_user_profile()
	user_registered.emit(updated_profile)
	progress_loaded.emit(updated_profile)
	return {
		"ok": true,
		"message": "Perfil local actualizado.",
		"profile": updated_profile
	}


func _write_current_save_and_emit_progress_saved(reason: String) -> bool:
	if not _write_save_to_disk(false, reason):
		return false
	progress_saved.emit(get_current_user_profile())
	return true


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
	save_data["save_meta"] = {"last_saved_at": "", "last_saved_reason": "", "write_count": 0}
	_mark_save_dirty()


func _apply_resume_level_to_global_state(resume_state: Dictionary) -> Dictionary:
	var resume_track_key: String = str(resume_state.get("track_key", ""))
	Global.current_level = clampi(
		int(resume_state.get("level_number", Global.current_level)),
		1,
		Global.get_track_level_count(resume_track_key)
	)
	return resume_state


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
	save_status_changed.emit(get_save_status())


func _count_completed_levels(track_progress: Variant) -> int:
	var completed := 0
	if track_progress is Array:
		for entry in track_progress:
			if bool(entry):
				completed += 1
	return completed
