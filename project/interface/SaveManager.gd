extends Node

@warning_ignore("unused_signal")
signal user_registered(profile: Dictionary)
signal user_logged_in(profile: Dictionary)
signal user_logged_out()
@warning_ignore("unused_signal")
signal progress_saved(profile: Dictionary)
@warning_ignore("unused_signal")
signal progress_loaded(profile: Dictionary)
@warning_ignore("unused_signal")
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
const SAVE_NAME_MIN_LENGTH := 3
const SAVE_NAME_MAX_LENGTH := 40
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const SaveLocalStorageHelperScript := preload(
	"res://interface/save_local/persistence/SaveLocalStorageHelper.gd"
)
const SaveLocalStateHelperScript := preload(
	"res://interface/save_local/progress/SaveLocalStateHelper.gd"
)
const SaveLocalBootstrapServiceScript := preload(
	"res://interface/save_local/persistence/SaveLocalBootstrapService.gd"
)
const SaveLocalProfileServiceScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileService.gd"
)
const SaveLocalProgressServiceScript := preload(
	"res://interface/save_local/progress/SaveLocalProgressService.gd"
)
const SaveDataNormalizerScript := preload(
	"res://interface/save_local/data/SaveDataNormalizer.gd"
)
const SaveLocalResumeServiceScript := preload(
	"res://interface/save_local/progress/SaveLocalResumeService.gd"
)
const SaveLocalWriteCoordinatorScript := preload(
	"res://interface/save_local/persistence/SaveLocalWriteCoordinator.gd"
)

var save_data: Dictionary = {}
var current_user_key: String = "local_profile"
var has_unsaved_changes: bool = false
var last_saved_snapshot: String = ""
var _profile_helper: RefCounted = SaveLocalProfileHelperScript.new()
var _storage_helper: RefCounted = SaveLocalStorageHelperScript.new()
var _state_helper: RefCounted = SaveLocalStateHelperScript.new()
var _bootstrap_service
var _profile_service
var _progress_service
var _data_normalizer
var _resume_service
var _write_coordinator
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
	bootstrap_loader().load_data()


func update_local_profile(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return profile_service().update_local_profile(username, age, email, avatar_source_path)


func save_current_user_progress(write_to_disk: bool = true) -> void:
	progress_service().save_current_user_progress(write_to_disk)


func load_current_user_progress(should_emit_progress_signal: bool = true) -> void:
	progress_service().load_current_user_progress(should_emit_progress_signal)


func load_current_save_and_get_resume_state(
	should_emit_progress_signal: bool = false
) -> Dictionary:
	return progress_service().load_current_save_and_get_resume_state(
		should_emit_progress_signal
	)


func record_manual_save() -> void:
	resume_service().record_manual_save()


func reset_all_progress() -> Dictionary:
	return progress_service().reset_all_progress()


func start_new_game(title: String = "") -> bool:
	return progress_service().start_new_game(title)


func register_user(
	username: String,
	_password: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return update_local_profile(username, age, email, avatar_source_path)


func login_user(_identifier: String, _password: String) -> Dictionary:
	load_current_user_progress(false)
	var profile := get_current_user_profile()
	user_logged_in.emit(profile)
	return {
		"ok": true,
		"message": "La persistencia local ya esta activa en este dispositivo.",
		"profile": profile
	}


func logout() -> void:
	save_current_user_progress()
	user_logged_out.emit()


func load_avatar_texture(path: String) -> Texture2D:
	return profile_service().load_avatar_texture(path)


func get_current_user_avatar_texture() -> Texture2D:
	return profile_service().get_current_user_avatar_texture()

func set_resume_to_book(track_key: String, allow_level_downgrade: bool = false) -> void:
	resume_service().set_resume_to_book(track_key, allow_level_downgrade)


func set_resume_to_level(track_key: String, level_number: int = -1) -> void:
	resume_service().set_resume_to_level(track_key, level_number)


func set_resume_after_level_completed(track_key: String, level_number: int) -> void:
	resume_service().set_resume_after_level_completed(track_key, level_number)


func get_resume_state() -> Dictionary:
	return resume_service().get_resume_state()


func get_current_resume_hint() -> String:
	return resume_service().get_current_resume_hint()


func can_resume_current_save() -> bool:
	return resume_service().can_resume_current_save()


func record_level_completed(track_key: String, level_number: int) -> void:
	resume_service().record_level_completed(track_key, level_number)

func is_authenticated() -> bool:
	return not get_current_user_profile().is_empty()


func has_accounts() -> bool:
	return is_authenticated()


func get_users_count() -> int:
	return 1 if is_authenticated() else 0


func get_last_user_hint() -> String:
	return str(get_current_user_profile().get("username", DEFAULT_PROFILE_NAME))


func get_current_user_profile() -> Dictionary:
	return profile_service().get_current_user_profile()


func get_save_status() -> Dictionary:
	return write_coordinator().get_save_status()


func notify_save_status_changed() -> void:
	emit_signal("save_status_changed", get_save_status())


func get_current_save_id() -> String:
	return LOCAL_SAVE_ID if can_resume_current_save() else ""


func get_current_save_summary() -> Dictionary:
	return _build_current_save_summary()


func list_available_saves(include_empty: bool = false) -> Array:
	var current_save_summary: Dictionary = _build_current_save_summary()
	if current_save_summary.is_empty():
		return []
	if include_empty or bool(current_save_summary.get("can_resume", false)):
		return [current_save_summary]
	return []


func get_current_save_history() -> Array:
	var history: Variant = save_data.get("history", [])
	return history.duplicate(true) if history is Array else []


func validate_save_name(title: String) -> Dictionary:
	return progress_state_helper().validate_save_name(
		title,
		SAVE_NAME_MIN_LENGTH,
		SAVE_NAME_MAX_LENGTH
	)


func summarize_progress_data(progress: Variant) -> Dictionary:
	return progress_state_helper().summarize_progress_data(
		progress,
		Global.get_track_keys(),
		Global.get_track_level_counts()
	)

func _ensure_runtime_services() -> void:
	if _profile_service == null:
		_profile_service = SaveLocalProfileServiceScript.new(self)
	if _resume_service == null:
		_resume_service = SaveLocalResumeServiceScript.new(self)
	if _progress_service == null:
		_progress_service = SaveLocalProgressServiceScript.new(self)
	if _bootstrap_service == null:
		_bootstrap_service = SaveLocalBootstrapServiceScript.new(self)
	if _write_coordinator == null:
		_write_coordinator = SaveLocalWriteCoordinatorScript.new(self)


func _ensure_data_normalizer() -> void:
	if _data_normalizer != null:
		return
	_data_normalizer = SaveDataNormalizerScript.new(
		profile_data_helper(),
		progress_state_helper(),
		_build_normalizer_context()
	)


func _build_normalizer_context() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"default_profile_name": DEFAULT_PROFILE_NAME,
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


func data_normalizer():
	_ensure_data_normalizer()
	return _data_normalizer


func bootstrap_loader():
	_ensure_runtime_services()
	return _bootstrap_service


func profile_service():
	_ensure_runtime_services()
	return _profile_service


func progress_service():
	_ensure_runtime_services()
	return _progress_service


func resume_service():
	_ensure_runtime_services()
	return _resume_service


func write_coordinator():
	_ensure_runtime_services()
	return _write_coordinator


func storage_helper():
	return _storage_helper


func profile_data_helper():
	return _profile_helper


func progress_state_helper():
	return _state_helper

func _build_current_save_summary() -> Dictionary:
	var can_resume: bool = can_resume_current_save()
	if not can_resume:
		return {}

	var resume_state: Dictionary = get_resume_state()
	var progress_summary: Dictionary = summarize_progress_data(save_data.get("progress", {}))
	var profile: Dictionary = get_current_user_profile()
	var raw_save_meta: Variant = save_data.get("save_meta", {})
	var save_meta: Dictionary = data_normalizer().default_save_meta()
	if raw_save_meta is Dictionary:
		save_meta = data_normalizer().normalize_save_meta(raw_save_meta)

	return {
		"id": LOCAL_SAVE_ID,
		"title": LOCAL_SAVE_TITLE,
		"created_at": str(profile.get("created_at", "")),
		"updated_at": _resolve_current_save_updated_at(profile, save_meta),
		"resume_hint": _format_resume_hint_from_state(resume_state),
		"resume_context": str(resume_state.get("context", RESUME_CONTEXT_HUB)),
		"resume_track_key": str(resume_state.get("track_key", "")),
		"resume_level_number": int(resume_state.get("level_number", 1)),
		"progress_summary": progress_summary,
		"can_resume": can_resume,
		"is_active": true
	}


func _resolve_current_save_updated_at(profile: Dictionary, save_meta: Dictionary) -> String:
	var updated_at: String = str(save_meta.get("last_saved_at", ""))
	if not updated_at.is_empty():
		return updated_at
	updated_at = str(profile.get("updated_at", ""))
	if not updated_at.is_empty():
		return updated_at
	return str(profile.get("created_at", ""))


func _format_resume_hint_from_state(resume_state: Dictionary) -> String:
	return progress_state_helper().format_resume_hint_from_state(
		resume_state,
		RESUME_CONTEXT_HUB,
		RESUME_CONTEXT_BOOK,
		RESUME_CONTEXT_LEVEL,
		Global.get_track_labels()
	)
