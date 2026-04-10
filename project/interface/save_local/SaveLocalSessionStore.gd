extends RefCounted

const SaveLocalSessionRuntimeServiceScript := preload("res://interface/save_local/SaveLocalSessionRuntimeService.gd")
const SaveLocalSessionResumeServiceScript := preload("res://interface/save_local/SaveLocalSessionResumeService.gd")

var _manager
var _runtime_service
var _resume_service


func _init(manager):
	_manager = manager
	_runtime_service = SaveLocalSessionRuntimeServiceScript.new(manager)
	_resume_service = SaveLocalSessionResumeServiceScript.new(manager)


func project_active_session_to_runtime() -> void:
	_runtime_service.project_active_session_to_runtime()


func get_active_session_data() -> Dictionary:
	return _runtime_service.get_active_session_data()


func get_session_data(session_id: String) -> Dictionary:
	return _runtime_service.get_session_data(session_id)


func get_session_resume_state(session_id: String) -> Dictionary:
	var session: Dictionary = get_session_data(session_id)
	if session.is_empty():
		return _manager._default_resume_state()
	return _resume_service.resolve_resume_state(_manager._normalize_resume_state(session.get("resume_state", {})))


func has_active_session() -> bool:
	return _runtime_service.has_active_session()


func activate_session(session_id: String) -> bool:
	return _runtime_service.activate_session(session_id)


func create_session(title: String = "", activate: bool = true) -> Dictionary:
	return _runtime_service.create_session(title, activate)


func rename_active_session(title: String) -> void:
	_runtime_service.rename_active_session(title)


func reset_runtime_session_projection() -> void:
	_runtime_service.reset_runtime_session_projection()


func sync_active_session_to_storage(save_meta: Dictionary) -> void:
	_runtime_service.sync_active_session_to_storage(save_meta)


func ensure_active_session_for_write(reason: String) -> void:
	_runtime_service.ensure_active_session_for_write(reason)


func build_session_summary(session: Dictionary) -> Dictionary:
	return _resume_service.build_session_summary(session)


func sort_save_slot_summaries(left: Dictionary, right: Dictionary) -> bool:
	return _resume_service.sort_save_slot_summaries(left, right)


func session_can_resume(session: Dictionary) -> bool:
	return _resume_service.session_can_resume(session)


func runtime_projection_has_session_content() -> bool:
	return _resume_service.runtime_projection_has_session_content()


func resolve_resume_state(normalized_resume_state: Dictionary) -> Dictionary:
	return _resume_service.resolve_resume_state(normalized_resume_state)


func derive_resume_state_from_history() -> Dictionary:
	return _resume_service.derive_resume_state_from_history()


func resume_state_from_history_metadata(metadata: Dictionary) -> Dictionary:
	return _resume_service.resume_state_from_history_metadata(metadata)


func resume_state_after_completed_level(metadata: Dictionary) -> Dictionary:
	return _resume_service.resume_state_after_completed_level(metadata)


func is_saved_level_completed(track_key: String, level_number: int) -> bool:
	return _resume_service.is_saved_level_completed(track_key, level_number)