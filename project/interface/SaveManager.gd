extends Node

signal user_registered(profile: Dictionary)
signal user_logged_in(profile: Dictionary)
signal user_logged_out()
signal progress_saved(profile: Dictionary)
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
const BOOK_SCENES := {
	"celiaquia": "res://interface/libro.tscn",
	"veganismo": "res://interface/libro-vegan.tscn",
	"veganismo_celiaquia": "res://interface/Libro-Vegan-GF.tscn"
}
const LEVEL_SCENES := {
	"celiaquia": "res://niveles/nivel_1/Level.tscn",
	"veganismo": "res://niveles/nivel_2/level_vegan.tscn",
	"veganismo_celiaquia": "res://niveles/nivel_3/Level-Vegan-GF.tscn"
}
const RESUME_CONTEXT_HUB := "hub"
const RESUME_CONTEXT_BOOK := "book"
const RESUME_CONTEXT_LEVEL := "level"
const SESSION_TITLE_PREFIX := "Partida"
const SESSION_ID_PREFIX := "session_"
const SESSION_TITLE_MIN_LENGTH := 3
const SESSION_TITLE_MAX_LENGTH := 40
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]

var save_data: Dictionary = {}
var current_user_key := "local_profile"
var has_unsaved_changes := false
var last_saved_snapshot := ""
var runtime_save_status := {
	"state": "idle",
	"last_loaded_from": "default",
	"recovered_from": "",
	"last_error": ""
}


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_user_progress()


func load_data() -> void:
	save_data = _default_save_data()
	var load_result := _load_available_save_data()
	var needs_write := false
	var loaded_from := "default"
	var recovered_from := ""

	if bool(load_result.get("ok", false)):
		save_data = _normalize_save_data(load_result.get("data", {}))
		loaded_from = str(load_result.get("source", "primary"))
		if loaded_from != "primary":
			recovered_from = loaded_from
			needs_write = true
	else:
		save_data = _default_save_data()
		needs_write = true

	if _ensure_local_profile():
		needs_write = true
	_project_active_session_to_runtime()
	if _repair_resume_state():
		needs_write = true

	if needs_write:
		if _write_save_data(true, "load_repair"):
			if recovered_from.is_empty():
				_emit_save_status("ready", loaded_from)
			else:
				_emit_save_status("recovered", "primary", recovered_from)
		else:
			_emit_save_status("error", loaded_from, recovered_from, "No se pudo restaurar el save principal en disco.")
	else:
		last_saved_snapshot = _serialize_save_data()
		has_unsaved_changes = false
		_emit_save_status("ready", loaded_from)

	Global.import_progress(save_data.get("progress", {}))


func is_authenticated() -> bool:
	return not get_current_user_profile().is_empty()


func has_accounts() -> bool:
	return is_authenticated()


func get_users_count() -> int:
	return 1 if is_authenticated() else 0


func get_last_user_hint() -> String:
	return str(get_current_user_profile().get("username", DEFAULT_PROFILE_NAME))


func update_local_profile(username: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	var validation := _validate_profile(username, age, email, avatar_source_path)
	if not validation["ok"]:
		return validation

	var clean_username := username.strip_edges()
	var clean_email := email.strip_edges()
	var clean_avatar_path := avatar_source_path.strip_edges()
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var profile := get_current_user_profile()
	var previous_avatar_path := str(profile.get("avatar_path", "")).strip_edges()

	if clean_username.is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
	else:
		profile["username"] = clean_username
	profile["age"] = max(0, age)
	profile["email"] = clean_email
	if clean_avatar_path.is_empty():
		_remove_managed_avatar(previous_avatar_path)
		profile["avatar_path"] = ""
	else:
		var persisted_avatar_path := _persist_avatar(current_user_key, clean_avatar_path)
		if persisted_avatar_path.is_empty():
			return {"ok": false, "message": "No se pudo copiar la foto seleccionada al almacenamiento local."}
		if persisted_avatar_path != previous_avatar_path:
			_remove_managed_avatar(previous_avatar_path)
		profile["avatar_path"] = persisted_avatar_path
	profile["updated_at"] = timestamp
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = timestamp

	save_data["profile"] = profile
	_mark_dirty()
	_append_history("Perfil local actualizado", {"type": "profile_updated"})
	save_current_user_progress(false)
	if not _write_save_data(false, "profile_updated"):
		return {"ok": false, "message": "No se pudo escribir el perfil local en disco."}

	var updated_profile := get_current_user_profile()
	user_registered.emit(updated_profile)
	user_logged_in.emit(updated_profile)
	progress_loaded.emit(updated_profile)
	return {"ok": true, "message": "Perfil local actualizado.", "profile": updated_profile}


func register_user(username: String, password: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	return update_local_profile(username, age, email, avatar_source_path)


func login_user(identifier: String, password: String) -> Dictionary:
	load_current_user_progress(false)
	var profile := get_current_user_profile()
	user_logged_in.emit(profile)
	return {"ok": true, "message": "La persistencia local ya esta activa en este dispositivo.", "profile": profile}


func logout() -> void:
	save_current_user_progress()
	user_logged_out.emit()


func save_current_user_progress(write_to_disk: bool = true) -> void:
	var profile := get_current_user_profile()
	save_data["profile"] = profile
	save_data["progress"] = Global.export_progress()
	_mark_dirty()

	if write_to_disk:
		if _write_save_data(false, "progress_sync"):
			progress_saved.emit(get_current_user_profile())


func load_current_user_progress(emit_signal: bool = true) -> void:
	Global.import_progress(save_data.get("progress", {}))
	if emit_signal:
		progress_loaded.emit(get_current_user_profile())


func load_progress_and_get_resume_state(emit_signal: bool = false) -> Dictionary:
	load_data()
	if not _has_active_session():
		var recent_session_id := get_recent_save_slot_id()
		if not recent_session_id.is_empty():
			_activate_session(recent_session_id)
	load_current_user_progress(emit_signal)
	var resume_state := get_resume_state()
	Global.current_level = clampi(int(resume_state.get("level_number", Global.current_level)), 1, Global.LEVELS_PER_BOOK)
	return resume_state


func load_slot_and_get_resume_state(session_id: String, emit_signal: bool = false) -> Dictionary:
	load_data()
	if not _activate_session(session_id):
		return _default_resume_state()
	load_current_user_progress(emit_signal)
	var resume_state := get_resume_state()
	Global.current_level = clampi(int(resume_state.get("level_number", Global.current_level)), 1, Global.LEVELS_PER_BOOK)
	return resume_state


func list_save_slots(include_empty: bool = false) -> Array:
	var slots: Array = []
	var sessions = save_data.get("sessions", {})
	if sessions is Dictionary:
		for raw_session_id in sessions.keys():
			var session_id := str(raw_session_id)
			if not sessions[session_id] is Dictionary:
				continue
			var summary := _build_session_summary(_normalize_session_data(sessions[session_id], session_id))
			if include_empty or bool(summary.get("can_resume", false)):
				slots.append(summary)
	slots.sort_custom(_sort_save_slot_summaries)
	return slots


func get_recent_save_slot_id() -> String:
	var slots := list_save_slots()
	if slots.is_empty():
		return ""
	return str(slots[0].get("id", ""))


func get_active_save_slot_id() -> String:
	return str(save_data.get("active_session_id", "")).strip_edges()


func get_active_save_slot_summary() -> Dictionary:
	var active_session := _get_active_session_data()
	if active_session.is_empty():
		return {}
	return _build_session_summary(active_session)


func validate_session_title(title: String) -> Dictionary:
	var clean_title := _normalize_session_title_value(title)
	if clean_title.is_empty():
		return {"ok": true, "title": "", "message": ""}
	if clean_title.length() < SESSION_TITLE_MIN_LENGTH:
		return {
			"ok": false,
			"title": clean_title,
			"message": "Usa al menos %d caracteres para identificar la partida." % SESSION_TITLE_MIN_LENGTH
		}
	if clean_title.length() > SESSION_TITLE_MAX_LENGTH:
		return {
			"ok": false,
			"title": clean_title.left(SESSION_TITLE_MAX_LENGTH),
			"message": "El nombre puede tener hasta %d caracteres." % SESSION_TITLE_MAX_LENGTH
		}
	return {"ok": true, "title": clean_title, "message": ""}


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	var current_resume_state := get_resume_state()
	if not allow_level_downgrade and str(current_resume_state.get("context", RESUME_CONTEXT_HUB)) == RESUME_CONTEXT_LEVEL:
		return
	_set_resume_state({
		"context": RESUME_CONTEXT_BOOK,
		"track_key": track_key,
		"scene_path": _get_book_scene_path(track_key),
		"level_number": clampi(Global.current_level, 1, Global.LEVELS_PER_BOOK)
	})


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	var resolved_level: int = Global.current_level if level_number < 1 else level_number
	_set_resume_state({
		"context": RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": _get_level_scene_path(track_key),
		"level_number": clampi(resolved_level, 1, Global.LEVELS_PER_BOOK)
	})


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	if level_number < Global.LEVELS_PER_BOOK:
		set_resume_to_level(track_key, level_number + 1)
		return
	_set_resume_state(_default_resume_state())


func get_resume_state() -> Dictionary:
	var raw_resume_state = save_data.get("resume_state", {})
	if not raw_resume_state is Dictionary:
		return _resolve_resume_state(_default_resume_state())
	return _resolve_resume_state(_normalize_resume_state(raw_resume_state))


func get_resume_hint(session_id: String = "") -> String:
	var resume_state := get_resume_state() if session_id.strip_edges().is_empty() else _get_session_resume_state(session_id)
	return _format_resume_hint_from_state(resume_state)


func can_resume_game(session_id: String = "") -> bool:
	var requested_session_id := session_id.strip_edges()
	if not requested_session_id.is_empty():
		return _session_can_resume(_get_session_data(requested_session_id))
	return not list_save_slots().is_empty()


func record_level_completed(track_key: String, level_number: int) -> void:
	set_resume_after_level_completed(track_key, level_number)
	save_current_user_progress(false)
	var message := "Completaste %s - capitulo %d" % [_track_label(track_key), level_number]
	_append_history(message, {
		"type": "level_completed",
		"track": track_key,
		"level": level_number,
		"session_id": get_active_save_slot_id()
	})
	if _write_save_data(false, "level_completed"):
		progress_saved.emit(get_current_user_profile())


func record_manual_save() -> void:
	save_current_user_progress(false)
	var resume_state := get_resume_state()
	_append_history("Guardado manual", {
		"type": "manual_save",
		"context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
		"track": str(resume_state.get("track_key", "")),
		"level": int(resume_state.get("level_number", Global.current_level)),
		"session_id": get_active_save_slot_id()
	})
	if _write_save_data(false, "manual_save"):
		progress_saved.emit(get_current_user_profile())


func reset_all_progress() -> Dictionary:
	var profile := get_current_user_profile()
	save_data["sessions"] = {}
	save_data["active_session_id"] = ""
	save_data["next_session_number"] = 1
	save_data["history"] = []
	save_data["resume_state"] = _default_resume_state()
	Global.reset_progress()
	save_data["progress"] = Global.export_progress()
	_mark_dirty()

	if not _write_save_data(false, "progress_reset"):
		return {"ok": false, "message": "No se pudo reiniciar el progreso local en disco."}

	progress_loaded.emit(profile)
	progress_saved.emit(profile)
	return {"ok": true, "message": "Se reinicio el progreso local.", "profile": profile}


func start_new_game(title: String = "") -> bool:
	load_data()
	var title_validation := validate_session_title(title)
	if not bool(title_validation.get("ok", false)):
		return false
	var normalized_title := str(title_validation.get("title", ""))
	var should_reuse_active_session := _has_active_session() and not _session_can_resume(_get_active_session_data())
	if _has_active_session() and not should_reuse_active_session:
		save_current_user_progress()

	_reset_runtime_session_projection()
	if should_reuse_active_session:
		_rename_active_session(normalized_title)
	else:
		_create_session(normalized_title, true)

	Global.reset_progress()
	save_current_user_progress(false)
	_append_history("Nueva partida iniciada", {
		"type": "new_game",
		"session_id": get_active_save_slot_id()
	})
	if not _write_save_data(false, "new_game"):
		return false
	var profile := get_current_user_profile()
	progress_loaded.emit(profile)
	progress_saved.emit(profile)
	return true


func get_current_user_profile() -> Dictionary:
	var user_record = save_data.get("profile", {})
	if not user_record is Dictionary:
		return {}
	return {
		"username": user_record.get("username", DEFAULT_PROFILE_NAME),
		"age": int(user_record.get("age", 0)),
		"email": user_record.get("email", ""),
		"avatar_path": user_record.get("avatar_path", ""),
		"created_at": user_record.get("created_at", ""),
		"updated_at": user_record.get("updated_at", "")
	}


func get_save_status() -> Dictionary:
	var save_meta = save_data.get("save_meta", {})
	if not save_meta is Dictionary:
		save_meta = _default_save_meta()
	var active_session_summary := get_active_save_slot_summary()
	return {
		"state": str(runtime_save_status.get("state", "idle")),
		"last_saved_at": str(save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(save_meta.get("last_saved_reason", "")),
		"write_count": int(save_meta.get("write_count", 0)),
		"last_loaded_from": str(runtime_save_status.get("last_loaded_from", "default")),
		"recovered_from": str(runtime_save_status.get("recovered_from", "")),
		"last_error": str(runtime_save_status.get("last_error", "")),
		"has_unsaved_changes": has_unsaved_changes,
		"session_id": str(active_session_summary.get("id", "")),
		"session_title": str(active_session_summary.get("title", "")),
		"session_count": list_save_slots(true).size()
	}


func get_current_user_history() -> Array:
	var history = save_data.get("history", [])
	return history.duplicate(true)


func load_avatar_texture(path: String) -> Texture2D:
	var avatar_path := path.strip_edges()
	if avatar_path.is_empty():
		return null

	var image := Image.new()
	var error := image.load(avatar_path)
	if error != OK:
		return null

	return ImageTexture.create_from_image(image)


func get_current_user_avatar_texture() -> Texture2D:
	var profile := get_current_user_profile()
	if profile.is_empty():
		return null
	return load_avatar_texture(str(profile.get("avatar_path", "")))


func _validate_profile(username: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	var clean_username := username.strip_edges()
	var clean_email := email.strip_edges()
	var clean_avatar_path := avatar_source_path.strip_edges()

	if not clean_username.is_empty() and clean_username.length() < 3:
		return {"ok": false, "message": "El nombre visible debe tener al menos 3 caracteres o quedar vacio."}
	if age < 0:
		return {"ok": false, "message": "La edad no puede ser negativa."}
	if not clean_email.is_empty() and not _is_valid_email(clean_email):
		return {"ok": false, "message": "Ingresa un mail valido o deja el campo vacio."}
	if not clean_avatar_path.is_empty() and load_avatar_texture(clean_avatar_path) == null:
		return {"ok": false, "message": "La foto seleccionada no se pudo abrir como imagen valida."}

	return {"ok": true}


func _default_save_data() -> Dictionary:
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
		"active_session_id": "",
		"next_session_number": 1,
		"sessions": {},
		"save_meta": _default_save_meta(),
		"resume_state": _default_resume_state(),
		"progress": {},
		"history": []
	}


func _default_save_meta() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0
	}


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	if raw_data.has("users"):
		raw_data = _migrate_legacy_save_data(raw_data)

	var normalized := _default_save_data()
	normalized["version"] = int(raw_data.get("version", SAVE_VERSION))

	var raw_profile = raw_data.get("profile", {})
	if raw_profile is Dictionary:
		normalized["profile"] = _normalize_profile_data(raw_profile)

	var raw_progress = raw_data.get("progress", {})
	if raw_progress is Dictionary:
		normalized["progress"] = raw_progress

	var raw_save_meta = raw_data.get("save_meta", {})
	if raw_save_meta is Dictionary:
		normalized["save_meta"] = _normalize_save_meta(raw_save_meta)

	var raw_resume_state = raw_data.get("resume_state", {})
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = _normalize_resume_state(raw_resume_state)

	normalized["history"] = _normalize_history(raw_data.get("history", []))

	var raw_sessions = raw_data.get("sessions", {})
	if raw_data.has("sessions") and raw_sessions is Dictionary:
		normalized["sessions"] = _normalize_sessions(raw_sessions)

	if normalized.get("sessions", {}).is_empty():
		var migrated_session := _migrate_single_session_data(raw_data)
		if not migrated_session.is_empty():
			var migrated_session_id := str(migrated_session.get("id", "%s0001" % SESSION_ID_PREFIX))
			var sessions: Dictionary = normalized["sessions"]
			sessions[migrated_session_id] = _normalize_session_data(migrated_session, migrated_session_id)
			normalized["sessions"] = sessions
			normalized["active_session_id"] = migrated_session_id
			normalized["next_session_number"] = 2

	var next_session_number: int = max(1, int(raw_data.get("next_session_number", normalized.get("next_session_number", 1))))
	next_session_number = max(next_session_number, int(normalized.get("sessions", {}).size()) + 1)
	normalized["next_session_number"] = next_session_number
	normalized["active_session_id"] = _sanitize_active_session_id(
		str(raw_data.get("active_session_id", normalized.get("active_session_id", ""))).strip_edges(),
		normalized.get("sessions", {})
	)

	return normalized


func _default_resume_state() -> Dictionary:
	return {
		"context": RESUME_CONTEXT_HUB,
		"track_key": "",
		"scene_path": ARCHIVERO_SCENE,
		"level_number": 1
	}


func _normalize_resume_state(raw_resume_state: Dictionary) -> Dictionary:
	var track_key := str(raw_resume_state.get("track_key", "")).strip_edges()
	var context := str(raw_resume_state.get("context", RESUME_CONTEXT_HUB)).strip_edges()
	var level_number := clampi(int(raw_resume_state.get("level_number", 1)), 1, Global.LEVELS_PER_BOOK)

	if context == RESUME_CONTEXT_BOOK and _is_known_track(track_key):
		return {
			"context": RESUME_CONTEXT_BOOK,
			"track_key": track_key,
			"scene_path": _get_book_scene_path(track_key),
			"level_number": level_number
		}

	if context == RESUME_CONTEXT_LEVEL and _is_known_track(track_key):
		return {
			"context": RESUME_CONTEXT_LEVEL,
			"track_key": track_key,
			"scene_path": _get_level_scene_path(track_key),
			"level_number": level_number
		}

	return _default_resume_state()


func _default_session_data(session_id: String = "", title: String = "", created_at: String = "") -> Dictionary:
	var timestamp := created_at if not created_at.is_empty() else Time.get_datetime_string_from_system(false, true)
	return {
		"id": session_id,
		"title": title,
		"created_at": timestamp,
		"updated_at": timestamp,
		"progress": {},
		"resume_state": _default_resume_state(),
		"history": [],
		"save_meta": _default_save_meta()
	}


func _normalize_session_data(raw_session: Dictionary, session_id: String = "") -> Dictionary:
	var normalized_session_id := session_id if not session_id.is_empty() else str(raw_session.get("id", "")).strip_edges()
	var created_at := str(raw_session.get("created_at", ""))
	var title := _normalize_session_title_value(str(raw_session.get("title", "")))
	if title.length() > SESSION_TITLE_MAX_LENGTH:
		title = title.left(SESSION_TITLE_MAX_LENGTH)
	var normalized := _default_session_data(normalized_session_id, title, created_at)
	if normalized["title"] == "":
		normalized["title"] = _build_default_session_title_from_id(normalized_session_id)
	normalized["updated_at"] = str(raw_session.get("updated_at", normalized.get("created_at", "")))

	var raw_progress = raw_session.get("progress", {})
	if raw_progress is Dictionary:
		normalized["progress"] = raw_progress.duplicate(true)

	var raw_resume_state = raw_session.get("resume_state", {})
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = _normalize_resume_state(raw_resume_state)

	var raw_history = raw_session.get("history", [])
	normalized["history"] = _normalize_history(raw_history)

	var raw_save_meta = raw_session.get("save_meta", {})
	if raw_save_meta is Dictionary:
		normalized["save_meta"] = _normalize_save_meta(raw_save_meta)

	if normalized["updated_at"] == "":
		normalized["updated_at"] = _session_updated_at(normalized)

	return normalized


func _normalize_sessions(raw_sessions: Variant) -> Dictionary:
	var normalized_sessions := {}
	if raw_sessions is Dictionary:
		for raw_session_id in raw_sessions.keys():
			var session_id := str(raw_session_id)
			if not raw_sessions[session_id] is Dictionary:
				continue
			normalized_sessions[session_id] = _normalize_session_data(raw_sessions[session_id], session_id)
	return normalized_sessions


func _migrate_single_session_data(raw_data: Dictionary) -> Dictionary:
	var migrated_progress = raw_data.get("progress", {})
	var migrated_resume_state = raw_data.get("resume_state", {})
	var migrated_history = raw_data.get("history", [])
	var migrated_save_meta = raw_data.get("save_meta", {})

	var candidate_session := {
		"id": "%s0001" % SESSION_ID_PREFIX,
		"title": _build_default_session_title(1),
		"created_at": str(raw_data.get("profile", {}).get("created_at", "")),
		"updated_at": str(migrated_save_meta.get("last_saved_at", "")),
		"progress": migrated_progress,
		"resume_state": migrated_resume_state,
		"history": migrated_history,
		"save_meta": migrated_save_meta
	}
	if not _session_can_resume(_normalize_session_data(candidate_session, str(candidate_session.get("id", "")))):
		return {}
	return candidate_session


func _sanitize_active_session_id(active_session_id: String, sessions: Dictionary) -> String:
	var clean_active_session_id := active_session_id.strip_edges()
	if not clean_active_session_id.is_empty() and sessions.has(clean_active_session_id) and sessions[clean_active_session_id] is Dictionary:
		return clean_active_session_id
	return _find_most_recent_session_id(sessions)


func _find_most_recent_session_id(sessions: Dictionary) -> String:
	var selected_session_id := ""
	var selected_updated_at := ""
	for raw_session_id in sessions.keys():
		var session_id := str(raw_session_id)
		if not sessions[session_id] is Dictionary:
			continue
		var session := _normalize_session_data(sessions[session_id], session_id)
		var updated_at := _session_updated_at(session)
		if selected_session_id.is_empty() or updated_at > selected_updated_at:
			selected_session_id = session_id
			selected_updated_at = updated_at
	return selected_session_id


func _project_active_session_to_runtime() -> void:
	var active_session := _get_active_session_data()
	if active_session.is_empty():
		save_data["progress"] = save_data.get("progress", {}) if save_data.get("progress", {}) is Dictionary else {}
		save_data["history"] = _normalize_history(save_data.get("history", []))
		save_data["resume_state"] = _normalize_resume_state(save_data.get("resume_state", {}))
		save_data["save_meta"] = _normalize_save_meta(save_data.get("save_meta", {}))
		return
	save_data["progress"] = active_session.get("progress", {}).duplicate(true)
	save_data["history"] = _normalize_history(active_session.get("history", []))
	save_data["resume_state"] = _normalize_resume_state(active_session.get("resume_state", {}))
	save_data["save_meta"] = _normalize_save_meta(active_session.get("save_meta", {}))


func _get_active_session_data() -> Dictionary:
	return _get_session_data(get_active_save_slot_id())


func _get_session_data(session_id: String) -> Dictionary:
	var sessions = save_data.get("sessions", {})
	if not sessions is Dictionary:
		return {}
	var clean_session_id := session_id.strip_edges()
	if clean_session_id.is_empty() or not sessions.has(clean_session_id) or not sessions[clean_session_id] is Dictionary:
		return {}
	return _normalize_session_data(sessions[clean_session_id], clean_session_id)


func _get_session_resume_state(session_id: String) -> Dictionary:
	var session := _get_session_data(session_id)
	if session.is_empty():
		return _default_resume_state()
	return _resolve_resume_state(_normalize_resume_state(session.get("resume_state", {})))


func _has_active_session() -> bool:
	return not _get_active_session_data().is_empty()


func _activate_session(session_id: String) -> bool:
	var session := _get_session_data(session_id)
	if session.is_empty():
		return false
	if str(save_data.get("active_session_id", "")) != str(session.get("id", "")):
		save_data["active_session_id"] = str(session.get("id", ""))
		_mark_dirty()
	_project_active_session_to_runtime()
	return true


func _create_session(title: String = "", activate: bool = true) -> Dictionary:
	var sessions = save_data.get("sessions", {})
	if not sessions is Dictionary:
		sessions = {}

	var next_session_number: int = max(1, int(save_data.get("next_session_number", 1)))
	var session_id := "%s%04d" % [SESSION_ID_PREFIX, next_session_number]
	while sessions.has(session_id):
		next_session_number += 1
		session_id = "%s%04d" % [SESSION_ID_PREFIX, next_session_number]

	var clean_title := _normalize_session_title_value(title)
	if clean_title.is_empty():
		clean_title = _build_default_session_title(next_session_number)
	elif clean_title.length() > SESSION_TITLE_MAX_LENGTH:
		clean_title = clean_title.left(SESSION_TITLE_MAX_LENGTH)

	var session := _default_session_data(session_id, clean_title)
	var progress = save_data.get("progress", {})
	if progress is Dictionary:
		session["progress"] = progress.duplicate(true)
	session["history"] = _normalize_history(save_data.get("history", []))
	session["resume_state"] = _normalize_resume_state(save_data.get("resume_state", {}))
	session["save_meta"] = _normalize_save_meta(save_data.get("save_meta", {}))
	session["updated_at"] = _session_updated_at(session)

	sessions[session_id] = session
	save_data["sessions"] = sessions
	save_data["next_session_number"] = next_session_number + 1
	if activate:
		save_data["active_session_id"] = session_id
		_project_active_session_to_runtime()
	_mark_dirty()
	return session.duplicate(true)


func _rename_active_session(title: String) -> void:
	var clean_title := _normalize_session_title_value(title)
	if clean_title.is_empty() or not _has_active_session():
		return
	if clean_title.length() > SESSION_TITLE_MAX_LENGTH:
		clean_title = clean_title.left(SESSION_TITLE_MAX_LENGTH)
	var active_session_id := get_active_save_slot_id()
	var sessions = save_data.get("sessions", {})
	if not sessions is Dictionary or not sessions.has(active_session_id) or not sessions[active_session_id] is Dictionary:
		return
	var session := _normalize_session_data(sessions[active_session_id], active_session_id)
	if str(session.get("title", "")) == clean_title:
		return
	session["title"] = clean_title
	sessions[active_session_id] = session
	save_data["sessions"] = sessions
	_mark_dirty()


func _reset_runtime_session_projection() -> void:
	save_data["progress"] = {}
	save_data["history"] = []
	save_data["resume_state"] = _default_resume_state()
	save_data["save_meta"] = _default_save_meta()
	_mark_dirty()


func _sync_active_session_to_storage(save_meta: Dictionary) -> void:
	var active_session_id := get_active_save_slot_id()
	if active_session_id.is_empty():
		return
	var sessions = save_data.get("sessions", {})
	if not sessions is Dictionary or not sessions.has(active_session_id) or not sessions[active_session_id] is Dictionary:
		return

	var session := _normalize_session_data(sessions[active_session_id], active_session_id)
	var progress = save_data.get("progress", {})
	if progress is Dictionary:
		session["progress"] = progress.duplicate(true)
	session["history"] = _normalize_history(save_data.get("history", []))
	session["resume_state"] = _normalize_resume_state(save_data.get("resume_state", {}))
	session["save_meta"] = save_meta.duplicate(true)
	session["updated_at"] = _session_updated_at(session)
	sessions[active_session_id] = session
	save_data["sessions"] = sessions


func _ensure_active_session_for_write(reason: String) -> void:
	if _has_active_session():
		return
	if reason == "profile_updated" or reason == "legacy_migration":
		return
	if reason == "load_repair" and not _runtime_projection_has_session_content():
		return
	if reason != "load_repair" and not _runtime_projection_has_session_content():
		return
	_create_session("", true)


func _build_default_session_title(session_number: int) -> String:
	return "%s %d" % [SESSION_TITLE_PREFIX, session_number]


func _normalize_session_title_value(title: String) -> String:
	var clean_title := title.strip_edges()
	for whitespace in ["\n", "\r", "\t"]:
		clean_title = clean_title.replace(whitespace, " ")
	while clean_title.contains("  "):
		clean_title = clean_title.replace("  ", " ")
	return clean_title


func _build_default_session_title_from_id(session_id: String) -> String:
	var clean_session_id := session_id.strip_edges()
	if clean_session_id.begins_with(SESSION_ID_PREFIX):
		var numeric_part := clean_session_id.trim_prefix(SESSION_ID_PREFIX)
		if numeric_part.is_valid_int():
			return _build_default_session_title(int(numeric_part))
	return SESSION_TITLE_PREFIX


func _build_session_summary(session: Dictionary) -> Dictionary:
	var progress_summary := _summarize_progress_data(session.get("progress", {}))
	var session_id := str(session.get("id", ""))
	var resume_state := _normalize_resume_state(session.get("resume_state", {}))
	return {
		"id": session_id,
		"title": str(session.get("title", _build_default_session_title_from_id(session_id))),
		"created_at": str(session.get("created_at", "")),
		"updated_at": _session_updated_at(session),
		"resume_hint": _format_resume_hint_from_state(resume_state),
		"resume_context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume_state.get("track_key", "")),
		"resume_level_number": int(resume_state.get("level_number", 1)),
		"progress_summary": progress_summary,
		"can_resume": _session_can_resume(session),
		"is_active": session_id == get_active_save_slot_id()
	}


func _sort_save_slot_summaries(left: Dictionary, right: Dictionary) -> bool:
	var left_updated_at := str(left.get("updated_at", ""))
	var right_updated_at := str(right.get("updated_at", ""))
	if left_updated_at == right_updated_at:
		return str(left.get("title", "")) < str(right.get("title", ""))
	return left_updated_at > right_updated_at


func _summarize_progress_data(progress: Variant) -> Dictionary:
	var progress_data: Dictionary = {}
	if progress is Dictionary:
		progress_data = progress
	var celiaquia_completed := _count_completed_progress_track(progress_data.get("celiaquia", []))
	var vegan_completed := _count_completed_progress_track(progress_data.get("veganismo", []))
	var vegan_gf_completed := _count_completed_progress_track(progress_data.get("veganismo_celiaquia", []))
	return {
		"celiaquia": celiaquia_completed,
		"veganismo": vegan_completed,
		"veganismo_celiaquia": vegan_gf_completed,
		"total": celiaquia_completed + vegan_completed + vegan_gf_completed,
		"max_total": Global.LEVELS_PER_BOOK * 3
	}


func _count_completed_progress_track(track_progress: Variant) -> int:
	var completed := 0
	if track_progress is Array:
		for entry in track_progress:
			if bool(entry):
				completed += 1
	return completed


func _session_can_resume(session: Dictionary) -> bool:
	if session.is_empty():
		return false
	var summary := _summarize_progress_data(session.get("progress", {}))
	if int(summary.get("total", 0)) > 0:
		return true
	var resume_state := _normalize_resume_state(session.get("resume_state", {}))
	if str(resume_state.get("context", RESUME_CONTEXT_HUB)) != RESUME_CONTEXT_HUB:
		return true
	var history = session.get("history", [])
	if history is Array:
		for entry in history:
			if not entry is Dictionary:
				continue
			var metadata = entry.get("metadata", {})
			if metadata is Dictionary and GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
				return true
	return false


func _runtime_projection_has_session_content() -> bool:
	return _session_can_resume({
		"progress": save_data.get("progress", {}),
		"resume_state": save_data.get("resume_state", {}),
		"history": save_data.get("history", [])
	})


func _session_updated_at(session: Dictionary) -> String:
	var updated_at := str(session.get("updated_at", ""))
	if not updated_at.is_empty():
		return updated_at
	var save_meta = session.get("save_meta", {})
	if save_meta is Dictionary:
		updated_at = str(save_meta.get("last_saved_at", ""))
	if not updated_at.is_empty():
		return updated_at
	return str(session.get("created_at", ""))


func _format_resume_hint_from_state(resume_state: Dictionary) -> String:
	var context := str(resume_state.get("context", RESUME_CONTEXT_HUB))
	var track_key := str(resume_state.get("track_key", ""))
	var level_number := int(resume_state.get("level_number", 1))

	match context:
		RESUME_CONTEXT_LEVEL:
			return "%s · capitulo %d" % [_track_label(track_key), level_number]
		RESUME_CONTEXT_BOOK:
			return "%s · seleccion de capitulos" % _track_label(track_key)
		_:
			return "el selector de modos"


func _repair_resume_state() -> bool:
	var stored_resume_state := _normalize_resume_state(save_data.get("resume_state", {}))
	var resolved_resume_state := _resolve_resume_state(stored_resume_state)
	if stored_resume_state == resolved_resume_state:
		return false
	save_data["resume_state"] = resolved_resume_state
	_mark_dirty()
	return true


func _resolve_resume_state(normalized_resume_state: Dictionary) -> Dictionary:
	var context := str(normalized_resume_state.get("context", RESUME_CONTEXT_HUB))
	if context == RESUME_CONTEXT_LEVEL:
		return normalized_resume_state

	var derived_resume_state := _derive_resume_state_from_history()
	if derived_resume_state.is_empty():
		return normalized_resume_state
	return derived_resume_state


func _derive_resume_state_from_history() -> Dictionary:
	var history = save_data.get("history", [])
	if not history is Array:
		return {}

	for entry in history:
		if not entry is Dictionary:
			continue
		var metadata = entry.get("metadata", {})
		if not metadata is Dictionary:
			continue

		var entry_type := str(metadata.get("type", "")).strip_edges()
		if entry_type == "new_game":
			return {}
		if entry_type == "manual_save":
			var saved_resume_state := _resume_state_from_history_metadata(metadata)
			if not saved_resume_state.is_empty():
				return saved_resume_state
		elif entry_type == "level_completed":
			var completed_resume_state := _resume_state_after_completed_level(metadata)
			if not completed_resume_state.is_empty():
				return completed_resume_state

	return {}


func _resume_state_from_history_metadata(metadata: Dictionary) -> Dictionary:
	var context := str(metadata.get("context", "")).strip_edges()
	var track_key := str(metadata.get("track", "")).strip_edges()
	if context != RESUME_CONTEXT_LEVEL or not _is_known_track(track_key):
		return {}

	return {
		"context": RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": _get_level_scene_path(track_key),
		"level_number": clampi(int(metadata.get("level", 1)), 1, Global.LEVELS_PER_BOOK)
	}


func _resume_state_after_completed_level(metadata: Dictionary) -> Dictionary:
	var track_key := str(metadata.get("track", "")).strip_edges()
	if not _is_known_track(track_key):
		return {}

	var completed_level := clampi(int(metadata.get("level", 1)), 1, Global.LEVELS_PER_BOOK)
	if not _is_saved_level_completed(track_key, completed_level):
		return {}
	if completed_level >= Global.LEVELS_PER_BOOK:
		return _default_resume_state()

	return {
		"context": RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": _get_level_scene_path(track_key),
		"level_number": completed_level + 1
	}


func _is_saved_level_completed(track_key: String, level_number: int) -> bool:
	var progress = save_data.get("progress", {})
	if not progress is Dictionary:
		return false

	var track_progress = progress.get(track_key, [])
	if not track_progress is Array:
		return false

	var level_index := level_number - 1
	if level_index < 0 or level_index >= track_progress.size():
		return false
	return bool(track_progress[level_index])


func _migrate_legacy_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized := _default_save_data()
	var raw_users = raw_data.get("users", {})
	var selected_user: Dictionary = {}
	var last_user_key := str(raw_data.get("last_user", ""))

	if raw_users is Dictionary:
		if raw_users.has(last_user_key) and raw_users[last_user_key] is Dictionary:
			selected_user = raw_users[last_user_key]
		elif raw_users.size() > 0:
			var first_key = raw_users.keys()[0]
			if raw_users[first_key] is Dictionary:
				selected_user = raw_users[first_key]

	if not selected_user.is_empty():
		normalized["profile"] = _normalize_profile_data({
			"username": selected_user.get("username", DEFAULT_PROFILE_NAME),
			"age": selected_user.get("age", 0),
			"email": selected_user.get("email", ""),
			"avatar_path": selected_user.get("avatar_path", ""),
			"created_at": selected_user.get("created_at", ""),
			"updated_at": selected_user.get("updated_at", "")
		})

		var migrated_progress = selected_user.get("progress", {})
		if migrated_progress is Dictionary:
			normalized["progress"] = migrated_progress

		normalized["save_meta"] = _normalize_save_meta({
			"last_saved_at": selected_user.get("updated_at", ""),
			"last_saved_reason": "legacy_migration",
			"write_count": 0
		})

		normalized["history"] = _normalize_history(selected_user.get("history", []))

	return normalized


func _normalize_profile_data(raw_profile: Dictionary) -> Dictionary:
	return {
		"username": str(raw_profile.get("username", DEFAULT_PROFILE_NAME)).strip_edges(),
		"age": max(0, int(raw_profile.get("age", 0))),
		"email": str(raw_profile.get("email", "")).strip_edges(),
		"avatar_path": str(raw_profile.get("avatar_path", "")).strip_edges(),
		"created_at": str(raw_profile.get("created_at", "")),
		"updated_at": str(raw_profile.get("updated_at", ""))
	}


func _normalize_save_meta(raw_save_meta: Dictionary) -> Dictionary:
	return {
		"last_saved_at": str(raw_save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(raw_save_meta.get("last_saved_reason", "")),
		"write_count": max(0, int(raw_save_meta.get("write_count", 0)))
	}


func _normalize_history(raw_history: Variant) -> Array:
	var history: Array = []
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				history.append(entry)
	return history


func _write_save_data(force: bool = false, reason: String = "save") -> bool:
	if not force and not has_unsaved_changes:
		return true

	_ensure_active_session_for_write(reason)

	var payload := save_data.duplicate(true)
	var save_meta := _normalize_save_meta(payload.get("save_meta", {}))
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = int(save_meta.get("write_count", 0)) + 1
	payload["save_meta"] = save_meta
	save_data["save_meta"] = save_meta
	_sync_active_session_to_storage(save_meta)
	payload = save_data.duplicate(true)

	var serialized := JSON.stringify(payload, "\t")

	var temp_file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if temp_file == null:
		_emit_save_status("error", str(runtime_save_status.get("last_loaded_from", "default")), str(runtime_save_status.get("recovered_from", "")), "No se pudo abrir el archivo temporal del save.")
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null

	if FileAccess.file_exists(SAVE_PATH) and not _copy_file(SAVE_PATH, BACKUP_SAVE_PATH):
		_emit_save_status("error", str(runtime_save_status.get("last_loaded_from", "default")), str(runtime_save_status.get("recovered_from", "")), "No se pudo generar el backup del save local.")
		return false

	_remove_file_if_exists(SAVE_PATH)
	if _move_file(TEMP_SAVE_PATH, SAVE_PATH) != OK:
		if FileAccess.file_exists(BACKUP_SAVE_PATH):
			_copy_file(BACKUP_SAVE_PATH, SAVE_PATH)
		_emit_save_status("error", str(runtime_save_status.get("last_loaded_from", "default")), str(runtime_save_status.get("recovered_from", "")), "No se pudo reemplazar el save principal.")
		return false

	save_data["save_meta"] = save_meta
	last_saved_snapshot = serialized
	has_unsaved_changes = false
	_emit_save_status("saved", str(runtime_save_status.get("last_loaded_from", "default")))
	return true


func _append_history(message: String, metadata: Dictionary = {}) -> void:
	var history: Array = save_data.get("history", [])
	history.push_front({
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(0, HISTORY_LIMIT)
	save_data["history"] = history
	_mark_dirty()


func _persist_avatar(user_key: String, source_path: String) -> String:
	var clean_source := source_path.strip_edges()
	if clean_source.is_empty():
		return ""

	var avatars_dir_absolute := ProjectSettings.globalize_path(AVATARS_DIR)
	DirAccess.make_dir_recursive_absolute(avatars_dir_absolute)

	var extension := clean_source.get_extension().to_lower()
	if extension.is_empty():
		extension = "png"

	var destination := "%s/%s.%s" % [AVATARS_DIR, _safe_file_key(user_key), extension]
	var source_file := FileAccess.open(clean_source, FileAccess.READ)
	if source_file == null:
		return ""

	var buffer := source_file.get_buffer(source_file.get_length())
	source_file = null
	var destination_file := FileAccess.open(destination, FileAccess.WRITE)
	if destination_file == null:
		return ""
	destination_file.store_buffer(buffer)
	destination_file.flush()
	destination_file = null
	return destination


func _remove_managed_avatar(path: String) -> void:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return
	if not clean_path.begins_with("%s/" % AVATARS_DIR):
		return
	_remove_file_if_exists(clean_path)


func _safe_file_key(raw_key: String) -> String:
	var safe_key := raw_key.to_lower().strip_edges()
	for character in [" ", "/", "\\", ":", ".", ",", ";", "\"", "'", "?", "!", "@", "#", "$", "%", "&", "(", ")", "[", "]", "{", "}"]:
		safe_key = safe_key.replace(character, "_")
	return safe_key


func _is_valid_email(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return regex.search(email) != null


func _ensure_local_profile() -> bool:
	var changed := false
	var profile = save_data.get("profile", {})
	if not profile is Dictionary:
		profile = {}
		changed = true

	profile = _normalize_profile_data(profile)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = DEFAULT_PROFILE_NAME
		changed = true

	var created_at := str(profile.get("created_at", ""))
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

	var save_meta = save_data.get("save_meta", {})
	if not save_meta is Dictionary:
		save_data["save_meta"] = _default_save_meta()
		changed = true
	else:
		save_data["save_meta"] = _normalize_save_meta(save_meta)

	var resume_state = save_data.get("resume_state", {})
	if not resume_state is Dictionary:
		save_data["resume_state"] = _default_resume_state()
		changed = true
	else:
		save_data["resume_state"] = _normalize_resume_state(resume_state)

	save_data["profile"] = profile
	current_user_key = "local_profile"
	if changed:
		_mark_dirty()
	return changed


func _load_available_save_data() -> Dictionary:
	for candidate_path in [SAVE_PATH, TEMP_SAVE_PATH, BACKUP_SAVE_PATH]:
		var candidate := _read_save_data_from_path(candidate_path)
		if bool(candidate.get("ok", false)):
			return {
				"ok": true,
				"data": candidate.get("data", {}),
				"source": _save_source_from_path(candidate_path)
			}
	return {"ok": false}


func _save_source_from_path(path: String) -> String:
	match path:
		SAVE_PATH:
			return "primary"
		TEMP_SAVE_PATH:
			return "temp"
		BACKUP_SAVE_PATH:
			return "backup"
		_:
			return "default"


func _read_save_data_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}

	var save_file := FileAccess.open(path, FileAccess.READ)
	if save_file == null:
		return {"ok": false}

	var file_contents := save_file.get_as_text()
	save_file = null
	if file_contents.strip_edges().is_empty():
		return {"ok": false}

	var json := JSON.new()
	if json.parse(file_contents) != OK:
		return {"ok": false}

	var parsed_data = json.data
	if parsed_data is Dictionary:
		return {"ok": true, "data": parsed_data}
	return {"ok": false}


func _serialize_save_data() -> String:
	return JSON.stringify(save_data, "\t")


func _copy_file(source_path: String, destination_path: String) -> bool:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false

	var file_contents := source_file.get_as_text()
	source_file = null
	_remove_file_if_exists(destination_path)

	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		return false
	destination_file.store_string(file_contents)
	destination_file.flush()
	destination_file = null
	return true


func _move_file(source_path: String, destination_path: String) -> int:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)


func _remove_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _set_resume_state(raw_resume_state: Dictionary) -> void:
	var normalized_resume_state := _normalize_resume_state(raw_resume_state)
	var current_resume_state := _normalize_resume_state(save_data.get("resume_state", {}))
	save_data["resume_state"] = normalized_resume_state
	if current_resume_state == normalized_resume_state:
		return
	_mark_dirty()


func _is_known_track(track_key: String) -> bool:
	return BOOK_SCENES.has(track_key) and LEVEL_SCENES.has(track_key)


func _get_book_scene_path(track_key: String) -> String:
	return str(BOOK_SCENES.get(track_key, ARCHIVERO_SCENE))


func _get_level_scene_path(track_key: String) -> String:
	return str(LEVEL_SCENES.get(track_key, ARCHIVERO_SCENE))


func _mark_dirty() -> void:
	if has_unsaved_changes:
		return
	has_unsaved_changes = true
	_emit_save_status("dirty", str(runtime_save_status.get("last_loaded_from", "default")))


func _emit_save_status(state: String, loaded_from: String = "", recovered_from: String = "", last_error: String = "") -> void:
	runtime_save_status["state"] = state
	if not loaded_from.is_empty():
		runtime_save_status["last_loaded_from"] = loaded_from
	runtime_save_status["recovered_from"] = recovered_from
	runtime_save_status["last_error"] = last_error
	save_status_changed.emit(get_save_status())


func _track_label(track_key: String) -> String:
	match track_key:
		"celiaquia":
			return "Celiaquia"
		"veganismo":
			return "Veganismo"
		"veganismo_celiaquia":
			return "Veganismo + Celiaquia"
		_:
			return "Tu progreso"
