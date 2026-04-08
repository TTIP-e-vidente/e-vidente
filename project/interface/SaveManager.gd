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
const RESUME_CONTEXT_HUB := "hub"
const RESUME_CONTEXT_BOOK := "book"
const RESUME_CONTEXT_LEVEL := "level"
const SESSION_TITLE_PREFIX := "Partida"
const SESSION_ID_PREFIX := "session_"
const SESSION_TITLE_MIN_LENGTH := 3
const SESSION_TITLE_MAX_LENGTH := 40
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]
const SaveLocalProfileHelperScript := preload("res://interface/save_local/SaveLocalProfileHelper.gd")
const SaveLocalStorageHelperScript := preload("res://interface/save_local/SaveLocalStorageHelper.gd")
const SaveLocalSessionHelperScript := preload("res://interface/save_local/SaveLocalSessionHelper.gd")
const SaveLocalBootstrapServiceScript := preload("res://interface/save_local/SaveLocalBootstrapService.gd")
const SaveLocalProfileServiceScript := preload("res://interface/save_local/SaveLocalProfileService.gd")
const SaveLocalProgressLifecycleServiceScript := preload("res://interface/save_local/SaveLocalProgressLifecycleService.gd")
const SaveDataNormalizerScript := preload("res://interface/save_local/SaveDataNormalizer.gd")
const SaveLocalSessionStoreScript := preload("res://interface/save_local/SaveLocalSessionStore.gd")
const SaveLocalResumeHistoryServiceScript := preload("res://interface/save_local/SaveLocalResumeHistoryService.gd")
const SaveLocalWriteCoordinatorScript := preload("res://interface/save_local/SaveLocalWriteCoordinator.gd")

var save_data: Dictionary = {}
var current_user_key := "local_profile"
var has_unsaved_changes := false
var last_saved_snapshot := ""
var _profile_helper = SaveLocalProfileHelperScript.new()
var _storage_helper = SaveLocalStorageHelperScript.new()
var _session_helper = SaveLocalSessionHelperScript.new()
var _bootstrap_service
var _profile_service
var _progress_lifecycle_service
var _data_normalizer
var _session_store
var _resume_history_service
var _write_coordinator
var runtime_save_status := {
	"state": "idle",
	"last_loaded_from": "default",
	"recovered_from": "",
	"last_error": ""
}


func _ready() -> void:
	_ensure_runtime_services()
	_ensure_data_normalizer()
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_user_progress()


func load_data() -> void:
	_ensure_runtime_services()
	_bootstrap_service.load_data()


func is_authenticated() -> bool:
	return not get_current_user_profile().is_empty()


func has_accounts() -> bool:
	return is_authenticated()


func get_users_count() -> int:
	return 1 if is_authenticated() else 0


func get_last_user_hint() -> String:
	return str(get_current_user_profile().get("username", DEFAULT_PROFILE_NAME))


func update_local_profile(username: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	_ensure_runtime_services()
	return _profile_service.update_local_profile(username, age, email, avatar_source_path)


func register_user(username: String, _password: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	return update_local_profile(username, age, email, avatar_source_path)


func login_user(_identifier: String, _password: String) -> Dictionary:
	load_current_user_progress(false)
	var profile := get_current_user_profile()
	user_logged_in.emit(profile)
	return {"ok": true, "message": "La persistencia local ya esta activa en este dispositivo.", "profile": profile}


func logout() -> void:
	save_current_user_progress()
	user_logged_out.emit()


func save_current_user_progress(write_to_disk: bool = true) -> void:
	_ensure_runtime_services()
	_progress_lifecycle_service.save_current_user_progress(write_to_disk)


func load_current_user_progress(should_emit_progress_signal: bool = true) -> void:
	_ensure_runtime_services()
	_progress_lifecycle_service.load_current_user_progress(should_emit_progress_signal)


func load_progress_and_get_resume_state(should_emit_progress_signal: bool = false) -> Dictionary:
	_ensure_runtime_services()
	return _progress_lifecycle_service.load_progress_and_get_resume_state(should_emit_progress_signal)


func load_slot_and_get_resume_state(session_id: String, should_emit_progress_signal: bool = false) -> Dictionary:
	_ensure_runtime_services()
	return _progress_lifecycle_service.load_slot_and_get_resume_state(session_id, should_emit_progress_signal)


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
	return _session_helper.validate_session_title(title, SESSION_TITLE_MIN_LENGTH, SESSION_TITLE_MAX_LENGTH)


func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	_ensure_runtime_services()
	_resume_history_service.set_resume_to_book(track_key, allow_level_downgrade)


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	_ensure_runtime_services()
	_resume_history_service.set_resume_to_level(track_key, level_number)


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	_ensure_runtime_services()
	_resume_history_service.set_resume_after_level_completed(track_key, level_number)


func get_resume_state() -> Dictionary:
	_ensure_runtime_services()
	return _resume_history_service.get_resume_state()


func get_resume_hint(session_id: String = "") -> String:
	_ensure_runtime_services()
	return _resume_history_service.get_resume_hint(session_id)


func can_resume_game(session_id: String = "") -> bool:
	_ensure_runtime_services()
	return _resume_history_service.can_resume_game(session_id)


func record_level_completed(track_key: String, level_number: int) -> void:
	_ensure_runtime_services()
	_resume_history_service.record_level_completed(track_key, level_number)


func record_manual_save() -> void:
	_ensure_runtime_services()
	_resume_history_service.record_manual_save()


func reset_all_progress() -> Dictionary:
	_ensure_runtime_services()
	return _progress_lifecycle_service.reset_all_progress()


func start_new_game(title: String = "") -> bool:
	_ensure_runtime_services()
	return _progress_lifecycle_service.start_new_game(title)


func get_current_user_profile() -> Dictionary:
	_ensure_runtime_services()
	return _profile_service.get_current_user_profile()


func get_save_status() -> Dictionary:
	_ensure_runtime_services()
	return _write_coordinator.get_save_status()


func get_current_user_history() -> Array:
	var history = save_data.get("history", [])
	return history.duplicate(true)


func load_avatar_texture(path: String) -> Texture2D:
	_ensure_runtime_services()
	return _profile_service.load_avatar_texture(path)


func get_current_user_avatar_texture() -> Texture2D:
	_ensure_runtime_services()
	return _profile_service.get_current_user_avatar_texture()


func _validate_profile(username: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	_ensure_runtime_services()
	return _profile_service.validate_profile(username, age, email, avatar_source_path)


func _ensure_runtime_services() -> void:
	if _profile_service == null:
		_profile_service = SaveLocalProfileServiceScript.new(self)
	if _session_store == null:
		_session_store = SaveLocalSessionStoreScript.new(self)
	if _resume_history_service == null:
		_resume_history_service = SaveLocalResumeHistoryServiceScript.new(self)
	if _progress_lifecycle_service == null:
		_progress_lifecycle_service = SaveLocalProgressLifecycleServiceScript.new(self)
	if _bootstrap_service == null:
		_bootstrap_service = SaveLocalBootstrapServiceScript.new(self)
	if _write_coordinator == null:
		_write_coordinator = SaveLocalWriteCoordinatorScript.new(self)


func _ensure_data_normalizer() -> void:
	if _data_normalizer != null:
		return
	_data_normalizer = SaveDataNormalizerScript.new(_profile_helper, _session_helper, _build_normalizer_context())


func _build_normalizer_context() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"default_profile_name": DEFAULT_PROFILE_NAME,
		"session_id_prefix": SESSION_ID_PREFIX,
		"session_title_prefix": SESSION_TITLE_PREFIX,
		"session_title_max_length": SESSION_TITLE_MAX_LENGTH,
		"gameplay_history_types": GAMEPLAY_HISTORY_TYPES,
		"archivero_scene": ARCHIVERO_SCENE,
		"resume_context_hub": RESUME_CONTEXT_HUB,
		"resume_context_book": RESUME_CONTEXT_BOOK,
		"resume_context_level": RESUME_CONTEXT_LEVEL,
		"levels_per_book": Global.LEVELS_PER_BOOK,
		"track_keys": Global.get_track_keys(),
		"track_level_counts": Global.get_track_level_counts(),
		"track_book_scene_paths": Global.get_track_book_scene_paths(),
		"track_level_scene_paths": Global.get_track_level_scene_paths()
	}


func _default_save_data() -> Dictionary:
	return _data_normalizer.default_save_data()


func _default_save_meta() -> Dictionary:
	return _data_normalizer.default_save_meta()


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	return _data_normalizer.normalize_save_data(raw_data)


func _default_resume_state() -> Dictionary:
	return _data_normalizer.default_resume_state()


func _normalize_resume_state(raw_resume_state: Dictionary) -> Dictionary:
	return _data_normalizer.normalize_resume_state(raw_resume_state)


func _default_session_data(session_id: String = "", title: String = "", created_at: String = "") -> Dictionary:
	return _data_normalizer.default_session_data(session_id, title, created_at)


func _normalize_session_data(raw_session: Dictionary, session_id: String = "") -> Dictionary:
	return _data_normalizer.normalize_session_data(raw_session, session_id)


func _normalize_sessions(raw_sessions: Variant) -> Dictionary:
	return _data_normalizer.normalize_sessions(raw_sessions)


func _migrate_single_session_data(raw_data: Dictionary) -> Dictionary:
	return _data_normalizer.migrate_single_session_data(raw_data)


func _sanitize_active_session_id(active_session_id: String, sessions: Dictionary) -> String:
	return _data_normalizer.sanitize_active_session_id(active_session_id, sessions)


func _find_most_recent_session_id(sessions: Dictionary) -> String:
	return _data_normalizer.find_most_recent_session_id(sessions)


func _project_active_session_to_runtime() -> void:
	_ensure_runtime_services()
	_session_store.project_active_session_to_runtime()


func _get_active_session_data() -> Dictionary:
	_ensure_runtime_services()
	return _session_store.get_active_session_data()


func _get_session_data(session_id: String) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.get_session_data(session_id)


func _get_session_resume_state(session_id: String) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.get_session_resume_state(session_id)


func _has_active_session() -> bool:
	_ensure_runtime_services()
	return _session_store.has_active_session()


func _activate_session(session_id: String) -> bool:
	_ensure_runtime_services()
	return _session_store.activate_session(session_id)


func _create_session(title: String = "", activate: bool = true) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.create_session(title, activate)


func _rename_active_session(title: String) -> void:
	_ensure_runtime_services()
	_session_store.rename_active_session(title)


func _reset_runtime_session_projection() -> void:
	_ensure_runtime_services()
	_session_store.reset_runtime_session_projection()


func _sync_active_session_to_storage(save_meta: Dictionary) -> void:
	_ensure_runtime_services()
	_session_store.sync_active_session_to_storage(save_meta)


func _ensure_active_session_for_write(reason: String) -> void:
	_ensure_runtime_services()
	_session_store.ensure_active_session_for_write(reason)


func _build_default_session_title(session_number: int) -> String:
	return _session_helper.build_default_session_title(SESSION_TITLE_PREFIX, session_number)


func _normalize_session_title_value(title: String) -> String:
	return _session_helper.normalize_session_title_value(title)


func _build_default_session_title_from_id(session_id: String) -> String:
	return _session_helper.build_default_session_title_from_id(SESSION_TITLE_PREFIX, SESSION_ID_PREFIX, session_id)


func _build_session_summary(session: Dictionary) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.build_session_summary(session)


func _sort_save_slot_summaries(left: Dictionary, right: Dictionary) -> bool:
	_ensure_runtime_services()
	return _session_store.sort_save_slot_summaries(left, right)


func _summarize_progress_data(progress: Variant) -> Dictionary:
	return _session_helper.summarize_progress_data(progress, Global.get_track_keys(), Global.get_track_level_counts())


func _count_completed_progress_track(track_progress: Variant) -> int:
	return _session_helper.count_completed_progress_track(track_progress)


func _session_can_resume(session: Dictionary) -> bool:
	_ensure_runtime_services()
	return _session_store.session_can_resume(session)


func _runtime_projection_has_session_content() -> bool:
	_ensure_runtime_services()
	return _session_store.runtime_projection_has_session_content()


func _session_updated_at(session: Dictionary) -> String:
	return _session_helper.session_updated_at(session)


func _format_resume_hint_from_state(resume_state: Dictionary) -> String:
	return _session_helper.format_resume_hint_from_state(
		resume_state,
		RESUME_CONTEXT_HUB,
		RESUME_CONTEXT_BOOK,
		RESUME_CONTEXT_LEVEL,
		Global.get_track_labels()
	)


func _repair_resume_state() -> bool:
	_ensure_runtime_services()
	return _resume_history_service.repair_resume_state()


func _resolve_resume_state(normalized_resume_state: Dictionary) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.resolve_resume_state(normalized_resume_state)


func _derive_resume_state_from_history() -> Dictionary:
	_ensure_runtime_services()
	return _session_store.derive_resume_state_from_history()


func _resume_state_from_history_metadata(metadata: Dictionary) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.resume_state_from_history_metadata(metadata)


func _resume_state_after_completed_level(metadata: Dictionary) -> Dictionary:
	_ensure_runtime_services()
	return _session_store.resume_state_after_completed_level(metadata)


func _is_saved_level_completed(track_key: String, level_number: int) -> bool:
	_ensure_runtime_services()
	return _session_store.is_saved_level_completed(track_key, level_number)


func _migrate_legacy_save_data(raw_data: Dictionary) -> Dictionary:
	return _data_normalizer.migrate_legacy_save_data(raw_data)


func _normalize_profile_data(raw_profile: Dictionary) -> Dictionary:
	return _data_normalizer.normalize_profile_data(raw_profile)


func _normalize_save_meta(raw_save_meta: Dictionary) -> Dictionary:
	return _data_normalizer.normalize_save_meta(raw_save_meta)


func _normalize_history(raw_history: Variant) -> Array:
	return _data_normalizer.normalize_history(raw_history)


func _write_save_data(force: bool = false, reason: String = "save") -> bool:
	_ensure_runtime_services()
	return _write_coordinator.write_save_data(force, reason)


func _append_history(message: String, metadata: Dictionary = {}) -> void:
	_ensure_runtime_services()
	_resume_history_service.append_history(message, metadata)


func _persist_avatar(user_key: String, source_path: String) -> String:
	return _profile_helper.persist_avatar(AVATARS_DIR, user_key, source_path)


func _remove_managed_avatar(path: String) -> void:
	_profile_helper.remove_managed_avatar(AVATARS_DIR, path)


func _safe_file_key(raw_key: String) -> String:
	return _profile_helper.safe_file_key(raw_key)


func _is_valid_email(email: String) -> bool:
	return _profile_helper.is_valid_email(email)


func _ensure_local_profile() -> bool:
	_ensure_runtime_services()
	return _profile_service.ensure_local_profile()


func _load_available_save_data() -> Dictionary:
	return _storage_helper.load_available_save_data(SAVE_PATH, TEMP_SAVE_PATH, BACKUP_SAVE_PATH)


func _save_source_from_path(path: String) -> String:
	return _storage_helper.save_source_from_path(path, SAVE_PATH, TEMP_SAVE_PATH, BACKUP_SAVE_PATH)


func _read_save_data_from_path(path: String) -> Dictionary:
	return _storage_helper.read_save_data_from_path(path)


func _serialize_save_data() -> String:
	return _storage_helper.serialize_save_data(save_data)


func _copy_file(source_path: String, destination_path: String) -> bool:
	return _storage_helper.copy_file(source_path, destination_path)


func _move_file(source_path: String, destination_path: String) -> int:
	return _storage_helper.move_file(source_path, destination_path)


func _remove_file_if_exists(path: String) -> void:
	_storage_helper.remove_file_if_exists(path)


func _set_resume_state(raw_resume_state: Dictionary) -> void:
	_ensure_runtime_services()
	_resume_history_service.set_resume_state(raw_resume_state)


func _is_known_track(track_key: String) -> bool:
	return Global.has_track(track_key)


func _get_book_scene_path(track_key: String) -> String:
	return Global.get_book_scene_path(track_key)


func _get_level_scene_path(track_key: String) -> String:
	return Global.get_level_scene_path(track_key)


func _mark_dirty() -> void:
	_ensure_runtime_services()
	_write_coordinator.mark_dirty()


func _emit_save_status(state: String, loaded_from: String = "", recovered_from: String = "", last_error: String = "") -> void:
	_ensure_runtime_services()
	_write_coordinator.emit_save_status(state, loaded_from, recovered_from, last_error)


func _notify_save_status_changed() -> void:
	save_status_changed.emit(get_save_status())


