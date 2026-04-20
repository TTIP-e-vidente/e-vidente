extends Node

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveDiskWriterScript := preload(
	"res://interface/save_local/write/SaveDiskWriter.gd"
)
const SaveDataSchemaScript := preload(
	"res://interface/save_local/data/SaveDataSchema.gd"
)
const SaveDataLoaderScript := preload(
	"res://interface/save_local/data/SaveDataLoader.gd"
)
const SaveResumeStateScript := preload(
	"res://interface/save_local/data/SaveResumeState.gd"
)

@warning_ignore("unused_signal")
signal user_registered(profile: Dictionary)
@warning_ignore("unused_signal")
signal progress_saved(profile: Dictionary)
@warning_ignore("unused_signal")
signal progress_loaded(profile: Dictionary)
signal save_status_changed(status: Dictionary)

const TEMP_SAVE_PATH := "user://save_data.tmp.json"
const AVATARS_DIR := "user://avatars"
const DEFAULT_PROFILE_NAME := SaveDataSchemaScript.DEFAULT_PROFILE_NAME
const SAVE_VERSION := SaveDataSchemaScript.SAVE_VERSION
const ARCHIVERO_SCENE := SaveDataSchemaScript.ARCHIVERO_SCENE
const RESUME_CONTEXT_HUB := SaveResumeStateScript.RESUME_CONTEXT_HUB
const RESUME_CONTEXT_BOOK := SaveResumeStateScript.RESUME_CONTEXT_BOOK
const RESUME_CONTEXT_LEVEL := SaveResumeStateScript.RESUME_CONTEXT_LEVEL
const LOCAL_SAVE_ID := "local_save"
const LOCAL_SAVE_TITLE := "Partida actual"
const LOCAL_PROFILE_KEY := "local_profile"
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]

var save_data: Dictionary = {}
var has_unsaved_changes: bool = false
var _save_state: String = "idle"
var _loaded_from: String = "default"
var _recovered_from: String = ""
var _last_error: String = ""

var _profile_helper: RefCounted
var _disk_writer: RefCounted
var _schema: RefCounted
var _data_loader: RefCounted
var _resume_helper: RefCounted


func _init() -> void:
	_profile_helper = SaveLocalProfileHelperScript.new()
	_disk_writer = SaveDiskWriterScript.new()
	_schema = SaveDataSchemaScript.new()
	_data_loader = SaveDataLoaderScript.new()
	_resume_helper = SaveResumeStateScript.new()


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress_to_disk()


func load_data() -> void:
	save_data = _data_loader.load_data()

	var needs_write: bool = bool(_data_loader.needs_write)
	var loaded_from: String = str(_data_loader.loaded_from)
	var recovered_from: String = str(_data_loader.recovered_from)
	var rewrite_reason: String = str(_data_loader.rewrite_reason)
	if _repair_loaded_save_data():
		needs_write = true

	if needs_write:
		_write_after_load_repair(
			loaded_from,
			recovered_from,
			rewrite_reason
		)
	else:
		has_unsaved_changes = false
		_emit_save_status("ready", loaded_from)

	var saved_progress: Variant = save_data.get("progress", {})
	Global.import_progress(saved_progress if saved_progress is Dictionary else {})
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
	var avatar_result: Dictionary = _update_profile_avatar(profile, avatar_source_path)
	if not bool(avatar_result.get("ok", false)):
		return avatar_result

	_apply_profile_identity_updates(profile, username, age, email)
	save_data["profile"] = profile
	return _persist_updated_profile()


func load_avatar_texture(path: String) -> Texture2D:
	return _profile_helper.load_avatar_texture(path)


func get_current_user_avatar_texture() -> Texture2D:
	var avatar_path: String = get_current_user_avatar_path()
	if avatar_path.is_empty():
		return null
	return load_avatar_texture(avatar_path)


func get_current_user_profile() -> Dictionary:
	var stored_profile: Variant = save_data.get("profile", {})
	if not stored_profile is Dictionary:
		return {}

	var profile: Dictionary = _profile_helper.normalize_profile_data(
		stored_profile,
		DEFAULT_PROFILE_NAME
	)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
	return profile


func get_current_user_name() -> String:
	var username: String = str(get_current_user_profile().get("username", DEFAULT_PROFILE_NAME)).strip_edges()
	return username if not username.is_empty() else DEFAULT_PROFILE_NAME


func get_current_user_email() -> String:
	return str(get_current_user_profile().get("email", "")).strip_edges()


func get_current_user_age() -> int:
	return max(0, int(get_current_user_profile().get("age", 0)))


func get_current_user_avatar_path() -> String:
	return str(get_current_user_profile().get("avatar_path", "")).strip_edges()


func get_current_save_state() -> String:
	return _save_state


func has_save_error() -> bool:
	return _save_state == "error"


func get_last_saved_at() -> String:
	return str(_get_save_meta().get("last_saved_at", ""))


func get_last_saved_reason() -> String:
	return str(_get_save_meta().get("last_saved_reason", ""))


func get_last_save_error() -> String:
	return _last_error.strip_edges()


func save_progress_to_disk() -> void:
	_save_current_state("progress_sync")


func record_manual_save() -> void:
	var resume: Dictionary = get_resume_state()
	_save_current_state(
		"manual_save",
		"Guardado manual",
		{
			"type": "manual_save",
			"context": str(resume.get("context", RESUME_CONTEXT_HUB)),
			"track": str(resume.get("track_key", "")),
			"level": int(resume.get("level_number", Global.current_level))
		}
	)


func record_level_completed(track_key: String, level_number: int) -> void:
	Global.clear_partial_level_state(track_key, level_number)
	_update_resume_after_completed_level(track_key, level_number)
	_save_current_state(
		"level_completed",
		_build_level_completed_message(track_key, level_number),
		{"type": "level_completed", "track": track_key, "level": level_number}
	)


func record_question_session_completed(question_count: int, score: int) -> void:
	if question_count < 1:
		return

	Global.record_streak_activity(
		"question_session_completed",
		{"question_count": question_count, "score": score}
	)
	_save_current_state(
		"question_session_completed",
		"Sesion de preguntas completada (%d/%d)" % [score, question_count],
		{
			"type": "question_session_completed",
			"question_count": question_count,
			"score": score
		}
	)


func reset_all_progress() -> Dictionary:
	var current_profile: Dictionary = get_current_user_profile()
	_reset_current_save_data(current_profile)
	if not _write_save_to_disk(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}
	progress_loaded.emit(current_profile)
	progress_saved.emit(current_profile)
	return {"ok": true, "message": "Se reinicio el progreso local.", "profile": current_profile}


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	if (
		not allow_level_downgrade
		and str(get_resume_state().get("context", RESUME_CONTEXT_HUB)) == RESUME_CONTEXT_LEVEL
	):
		return
	_store_resume_state(_resume_helper.build_for_book(track_key, Global.current_level))


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	var level: int = Global.current_level if level_number < 1 else level_number
	_store_resume_state(_resume_helper.build_for_level(track_key, level))


func get_resume_state() -> Dictionary:
	return _resume_helper.resolve_from_save(save_data, ARCHIVERO_SCENE)


func get_current_resume_hint() -> String:
	return _resume_helper.format_hint(get_resume_state())


func can_resume_current_save() -> bool:
	var summary: Dictionary = _summarize_progress(save_data.get("progress", {}))
	if int(summary.get("total", 0)) > 0:
		return true
	if str(get_resume_state().get("context", RESUME_CONTEXT_HUB)) != RESUME_CONTEXT_HUB:
		return true
	return _history_has_gameplay(save_data.get("history", []))


func reload_from_disk_and_get_resume() -> Dictionary:
	load_data()
	var resume_state: Dictionary = get_resume_state()
	Global.current_level = clampi(
		int(resume_state.get("level_number", Global.current_level)),
		1,
		Global.get_track_level_count(str(resume_state.get("track_key", "")))
	)
	return resume_state


func get_save_status() -> Dictionary:
	var meta: Dictionary = _get_save_meta()
	var save_summary: Dictionary = get_current_save_summary()
	return {
		"state": _save_state,
		"last_saved_at": str(meta.get("last_saved_at", "")),
		"last_saved_reason": str(meta.get("last_saved_reason", "")),
		"write_count": max(0, int(meta.get("write_count", 0))),
		"last_loaded_from": _loaded_from,
		"recovered_from": _recovered_from,
		"last_error": _last_error,
		"has_unsaved_changes": has_unsaved_changes,
		"save_id": str(save_summary.get("id", "")),
		"save_title": str(save_summary.get("title", "")),
		"save_count": 1 if not save_summary.is_empty() else 0
	}


func get_current_save_summary() -> Dictionary:
	if not can_resume_current_save():
		return {}

	var profile: Dictionary = get_current_user_profile()
	var meta: Dictionary = _get_save_meta()
	var resume: Dictionary = get_resume_state()
	var progress: Dictionary = _summarize_progress(save_data.get("progress", {}))
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
		"resume_hint": _resume_helper.format_hint(resume),
		"resume_context": str(resume.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume.get("track_key", "")),
		"resume_level_number": int(resume.get("level_number", 1)),
		"progress_summary": progress,
		"can_resume": true,
		"is_active": true
	}


func get_current_save_history() -> Array:
	var stored: Variant = save_data.get("history", [])
	return stored.duplicate(true) if stored is Array else []


func _get_save_meta() -> Dictionary:
	return _schema.normalize_save_meta(save_data.get("save_meta", {}))


func _repair_loaded_save_data() -> bool:
	var needs_write_after_repair: bool = false
	if _data_loader.repair_structure(save_data):
		_mark_save_dirty()
		needs_write_after_repair = true
	if _resume_helper.repair(save_data, ARCHIVERO_SCENE):
		_mark_save_dirty()
		needs_write_after_repair = true
	return needs_write_after_repair


func _update_profile_avatar(profile: Dictionary, avatar_source_path: String) -> Dictionary:
	var previous_avatar_path: String = str(profile.get("avatar_path", "")).strip_edges()
	return _profile_helper.apply_avatar_change(
		profile,
		avatar_source_path.strip_edges(),
		previous_avatar_path,
		AVATARS_DIR,
		LOCAL_PROFILE_KEY
	)


func _apply_profile_identity_updates(
	profile: Dictionary,
	username: String,
	age: int,
	email: String
) -> void:
	_profile_helper.apply_identity_changes(profile, username, age, email, DEFAULT_PROFILE_NAME)
	_profile_helper.stamp_timestamps(profile)


func _update_resume_after_completed_level(track_key: String, level_number: int) -> void:
	if level_number < Global.get_track_level_count(track_key):
		set_resume_to_level(track_key, level_number + 1)
		return
	_store_resume_state(_resume_helper.get_default_state(ARCHIVERO_SCENE))


func _build_level_completed_message(track_key: String, level_number: int) -> String:
	var track_label: String = GameTrackCatalog.get_track_label(track_key, track_key)
	return "Completaste %s - capitulo %d" % [track_label, level_number]


func _save_current_state(
	reason: String,
	history_message: String = "",
	history_metadata: Dictionary = {},
	emit_progress_saved: bool = true
) -> bool:
	save_data["profile"] = get_current_user_profile()
	save_data["progress"] = Global.export_progress()
	_mark_save_dirty()
	if not history_message.is_empty():
		_schema.append_history(save_data, history_message, history_metadata)
	if not _write_save_to_disk(false, reason):
		return false
	if emit_progress_saved:
		progress_saved.emit(get_current_user_profile())
	return true


func _store_resume_state(raw: Dictionary) -> void:
	var next_resume_state: Dictionary = _resume_helper.normalize(raw, ARCHIVERO_SCENE)
	var current_resume_state: Dictionary = _resume_helper.normalize(
		save_data.get("resume_state", {}),
		ARCHIVERO_SCENE
	)
	save_data["resume_state"] = next_resume_state
	if current_resume_state != next_resume_state:
		_mark_save_dirty()


func _write_save_to_disk(force: bool = false, reason: String = "save") -> bool:
	if not force and not has_unsaved_changes:
		return true

	var result: Dictionary = _disk_writer.write(save_data, _loaded_from, reason)
	if not bool(result.get("ok", false)):
		_emit_save_status(
			"error",
			_loaded_from,
			_recovered_from,
			str(result.get("error_message", "Error desconocido al guardar."))
		)
		return false

	if bool(result.get("wrote_primary", false)):
		_loaded_from = "primary"
		_recovered_from = ""

	has_unsaved_changes = false
	_emit_save_status("saved", _loaded_from, _recovered_from)
	return true


func _history_has_gameplay(raw_history: Variant) -> bool:
	if not raw_history is Array:
		return false
	for history_entry in raw_history:
		var metadata: Dictionary = _read_history_metadata(history_entry)
		if not metadata.is_empty() and GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
			return true
	return false


func _read_history_metadata(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var metadata: Variant = entry.get("metadata", {})
	return metadata if metadata is Dictionary else {}


func _summarize_progress(progress: Variant) -> Dictionary:
	var progress_data: Dictionary = progress if progress is Dictionary else {}
	var summary: Dictionary = {"total": 0, "max_total": 0}
	for raw_track_key in GameTrackCatalog.get_track_keys():
		var track_key: String = str(raw_track_key)
		var flags: Variant = progress_data.get(track_key, [])
		var completed: int = 0
		if flags is Array:
			for flag_value in flags:
				if bool(flag_value):
					completed += 1
		summary[track_key] = completed
		summary["total"] += completed
		summary["max_total"] += Global.get_track_level_count(track_key)
	return summary


func _reset_current_save_data(profile: Dictionary) -> void:
	Global.reset_progress()
	save_data["profile"] = profile
	save_data["progress"] = Global.export_progress()
	save_data["history"] = []
	save_data["resume_state"] = _resume_helper.get_default_state(ARCHIVERO_SCENE)
	save_data["save_meta"] = _empty_save_meta()
	_mark_save_dirty()


func _empty_save_meta() -> Dictionary:
	return {"last_saved_at": "", "last_saved_reason": "", "write_count": 0}


func _persist_updated_profile() -> Dictionary:
	if not _save_current_state(
		"profile_updated",
		"Perfil local actualizado",
		{"type": "profile_updated"},
		false
	):
		return {"ok": false, "message": "No se pudo escribir el perfil local en disco."}

	var updated_profile: Dictionary = get_current_user_profile()
	user_registered.emit(updated_profile)
	progress_loaded.emit(updated_profile)
	return {"ok": true, "message": "Perfil local actualizado.", "profile": updated_profile}


func _mark_save_dirty() -> void:
	if has_unsaved_changes:
		return
	has_unsaved_changes = true
	_emit_save_status("dirty", _loaded_from, _recovered_from)


func _emit_save_status(
	state: String,
	loaded_from: String = "",
	recovered_from: String = "",
	last_error: String = ""
) -> void:
	_save_state = state
	if not loaded_from.is_empty():
		_loaded_from = loaded_from
	_recovered_from = recovered_from
	_last_error = last_error
	save_status_changed.emit(get_save_status())


func _write_after_load_repair(
	loaded_from: String,
	recovered_from: String,
	reason: String
) -> void:
	_loaded_from = loaded_from
	_recovered_from = recovered_from
	var effective_reason: String = reason if not reason.is_empty() else "load_repair"
	if not _write_save_to_disk(true, effective_reason):
		if not recovered_from.is_empty() and FileAccess.file_exists(TEMP_SAVE_PATH):
			has_unsaved_changes = false
			_emit_save_status("recovered", loaded_from, recovered_from)
		else:
			_emit_save_status(
				"error",
				loaded_from,
				recovered_from,
				"No se pudo restaurar el save principal en disco."
			)
		return
	if recovered_from.is_empty():
		_emit_save_status("ready", _loaded_from)
	else:
		_emit_save_status("recovered", _loaded_from, recovered_from)
