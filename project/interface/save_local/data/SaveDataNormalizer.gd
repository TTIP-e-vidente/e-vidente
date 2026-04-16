extends RefCounted

const SaveLocalLegacyMigrationServiceScript := preload(
	"res://interface/save_local/data/SaveLocalLegacyMigrationService.gd"
)

var _profile_helper
var _state_helper
var _config: Dictionary = {}
var _legacy_migration_service


func _init(profile_helper, state_helper, config: Dictionary):
	_profile_helper = profile_helper
	_state_helper = state_helper
	_config = config.duplicate(true)
	var data_normalizer_ref: WeakRef = weakref(self)
	_legacy_migration_service = SaveLocalLegacyMigrationServiceScript.new(
		_profile_helper,
		_config,
		data_normalizer_ref
	)


func default_save_data() -> Dictionary:
	return {
		"version": int(_config.get("save_version", 1)),
		"profile": {
			"username": str(_config.get("default_profile_name", "Perfil local")),
			"age": 0,
			"email": "",
			"avatar_path": "",
			"created_at": "",
			"updated_at": ""
		},
		"save_meta": default_save_meta(),
		"resume_state": default_resume_state(),
		"progress": {},
		"history": []
	}


func default_save_meta() -> Dictionary:
	return _state_helper.default_save_meta()


func normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var source_data: Dictionary = _flatten_legacy_slots_if_needed(
		_migrate_legacy_root_if_needed(raw_data)
	)
	var normalized: Dictionary = default_save_data()
	normalized["version"] = int(source_data.get("version", int(_config.get("save_version", 1))))
	_apply_profile_section(normalized, source_data.get("profile", {}))
	_apply_progress_section(normalized, source_data.get("progress", {}))
	_apply_save_meta_section(normalized, source_data.get("save_meta", {}))
	_apply_resume_state_section(normalized, source_data.get("resume_state", {}))
	normalized["history"] = normalize_history(source_data.get("history", []))
	return normalized


func _migrate_legacy_root_if_needed(raw_data: Dictionary) -> Dictionary:
	if raw_data.has("users"):
		return _legacy_migration_service.migrate_legacy_save_data(raw_data)
	return raw_data


func _flatten_legacy_slots_if_needed(raw_data: Dictionary) -> Dictionary:
	var raw_legacy_slots: Variant = raw_data.get("sessions", {})
	if not raw_legacy_slots is Dictionary:
		return raw_data

	var selected_legacy_slot: Dictionary = _select_legacy_slot_state(
		raw_legacy_slots,
		str(raw_data.get("active_session_id", "")).strip_edges()
	)
	if selected_legacy_slot.is_empty():
		return raw_data

	var flattened: Dictionary = raw_data.duplicate(true)
	_apply_progress_section(flattened, selected_legacy_slot.get("progress", {}))
	_apply_save_meta_section(flattened, selected_legacy_slot.get("save_meta", {}))
	_apply_resume_state_section(flattened, selected_legacy_slot.get("resume_state", {}))
	flattened["history"] = normalize_history(selected_legacy_slot.get("history", []))
	return flattened


func _select_legacy_slot_state(
	raw_legacy_slots: Dictionary,
	active_session_id: String
) -> Dictionary:
	if (
		raw_legacy_slots.has(active_session_id)
		and raw_legacy_slots[active_session_id] is Dictionary
	):
		return raw_legacy_slots[active_session_id]

	var selected_legacy_slot: Dictionary = {}
	var selected_updated_at: String = ""
	for raw_slot_id in raw_legacy_slots.keys():
		var legacy_slot: Variant = raw_legacy_slots[raw_slot_id]
		if not legacy_slot is Dictionary:
			continue
		var updated_at: String = _state_helper.last_updated_at(legacy_slot)
		if selected_legacy_slot.is_empty() or updated_at > selected_updated_at:
			selected_legacy_slot = legacy_slot
			selected_updated_at = updated_at
	return selected_legacy_slot


func _apply_profile_section(normalized: Dictionary, raw_profile: Variant) -> void:
	if raw_profile is Dictionary:
		normalized["profile"] = normalize_profile_data(raw_profile)


func _apply_progress_section(normalized: Dictionary, raw_progress: Variant) -> void:
	if raw_progress is Dictionary:
		normalized["progress"] = raw_progress


func _apply_save_meta_section(normalized: Dictionary, raw_save_meta: Variant) -> void:
	if raw_save_meta is Dictionary:
		normalized["save_meta"] = normalize_save_meta(raw_save_meta)



func _apply_resume_state_section(normalized: Dictionary, raw_resume_state: Variant) -> void:
	if raw_resume_state is Dictionary:
		normalized["resume_state"] = normalize_resume_state(raw_resume_state)


func default_resume_state() -> Dictionary:
	return _state_helper.default_resume_state(
		str(_config.get("resume_context_hub", "hub")),
		str(_config.get("archivero_scene", ""))
	)


func normalize_resume_state(raw_resume_state: Dictionary) -> Dictionary:
	return _state_helper.normalize_resume_state(
		raw_resume_state,
		_config.get("track_book_scene_paths", {}),
		_config.get("track_level_scene_paths", {}),
		_config.get("track_level_counts", {}),
		str(_config.get("archivero_scene", "")),
		str(_config.get("resume_context_hub", "hub")),
		str(_config.get("resume_context_book", "book")),
		str(_config.get("resume_context_level", "level")),
		int(_config.get("levels_per_book", 1))
	)


func migrate_legacy_save_data(raw_data: Dictionary) -> Dictionary:
	return _legacy_migration_service.migrate_legacy_save_data(raw_data)


func normalize_profile_data(raw_profile: Dictionary) -> Dictionary:
	return _profile_helper.normalize_profile_data(
		raw_profile,
		str(_config.get("default_profile_name", "Perfil local"))
	)


func normalize_save_meta(raw_save_meta: Dictionary) -> Dictionary:
	return {
		"last_saved_at": str(raw_save_meta.get("last_saved_at", "")),
		"last_saved_reason": str(raw_save_meta.get("last_saved_reason", "")),
		"write_count": max(0, int(raw_save_meta.get("write_count", 0)))
	}


func normalize_history(raw_history: Variant) -> Array:
	var history: Array = []
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				history.append(entry)
	return history
