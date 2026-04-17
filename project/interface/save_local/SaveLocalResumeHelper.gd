extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const CONTEXT_HUB := "hub"
const CONTEXT_BOOK := "book"
const CONTEXT_LEVEL := "level"
const HISTORY_LIMIT := 25
const GAMEPLAY_HISTORY_TYPES := ["new_game", "manual_save", "level_completed"]


func default_resume_state() -> Dictionary:
	return {
		"context": CONTEXT_HUB,
		"track_key": "",
		"scene_path": ARCHIVERO_SCENE,
		"level_number": 1
	}


func normalize_resume_state(raw_resume_state: Variant) -> Dictionary:
	if not raw_resume_state is Dictionary:
		return default_resume_state()

	var stored_resume_state: Dictionary = raw_resume_state
	var context: String = str(stored_resume_state.get("context", CONTEXT_HUB)).strip_edges()
	var track_key: String = str(stored_resume_state.get("track_key", "")).strip_edges()
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track_key)
	if track_definition.is_empty():
		return default_resume_state()

	var level_number: int = clampi(
		int(stored_resume_state.get("level_number", 1)),
		1,
		Global.get_track_level_count(track_key)
	)
	if context == CONTEXT_BOOK:
		return {
			"context": CONTEXT_BOOK,
			"track_key": track_key,
			"scene_path": str(track_definition.get("book_scene_path", ARCHIVERO_SCENE)),
			"level_number": level_number
		}
	if context == CONTEXT_LEVEL:
		return {
			"context": CONTEXT_LEVEL,
			"track_key": track_key,
			"scene_path": str(track_definition.get("level_scene_path", ARCHIVERO_SCENE)),
			"level_number": level_number
		}
	return default_resume_state()


func get_resume_state(save_data: Dictionary) -> Dictionary:
	var normalized_resume_state: Dictionary = default_resume_state()
	var stored_resume_state: Variant = save_data.get("resume_state", {})
	if stored_resume_state is Dictionary:
		normalized_resume_state = normalize_resume_state(stored_resume_state)
	return _resolve_resume_state_with_history_fallback(save_data, normalized_resume_state)


func repair_resume_state(save_data: Dictionary) -> bool:
	var normalized_resume_state: Dictionary = default_resume_state()
	var stored_resume_state: Variant = save_data.get("resume_state", {})
	if stored_resume_state is Dictionary:
		normalized_resume_state = normalize_resume_state(stored_resume_state)
	var repaired_resume_state: Dictionary = _resolve_resume_state_with_history_fallback(
		save_data,
		normalized_resume_state
	)
	if normalized_resume_state == repaired_resume_state:
		return false
	save_data["resume_state"] = repaired_resume_state
	return true


func store_resume_state(save_data: Dictionary, raw_resume_state: Dictionary) -> bool:
	var resume_state_to_store: Dictionary = normalize_resume_state(raw_resume_state)
	var current_resume_state: Dictionary = normalize_resume_state(save_data.get("resume_state", {}))
	save_data["resume_state"] = resume_state_to_store
	return current_resume_state != resume_state_to_store


func build_resume_state_for_book(track_key: String, current_level: int) -> Dictionary:
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track_key)
	return {
		"context": CONTEXT_BOOK,
		"track_key": track_key,
		"scene_path": str(track_definition.get("book_scene_path", "")).strip_edges(),
		"level_number": clampi(current_level, 1, Global.get_track_level_count(track_key))
	}


func build_resume_state_for_level(track_key: String, level_number: int) -> Dictionary:
	var track_definition: Dictionary = GameTrackCatalog.get_track_definition(track_key)
	return {
		"context": CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": str(track_definition.get("level_scene_path", "")).strip_edges(),
		"level_number": clampi(level_number, 1, Global.get_track_level_count(track_key))
	}


func append_history(save_data: Dictionary, message: String, metadata: Dictionary = {}) -> void:
	var stored_history: Variant = save_data.get("history", [])
	var history_entries: Array = stored_history if stored_history is Array else []
	history_entries.push_front(_build_history_entry(message, metadata))
	if history_entries.size() > HISTORY_LIMIT:
		history_entries = history_entries.slice(0, HISTORY_LIMIT)
	save_data["history"] = history_entries


func get_history(save_data: Dictionary) -> Array:
	var stored_history: Variant = save_data.get("history", [])
	return stored_history.duplicate(true) if stored_history is Array else []


func history_has_gameplay_progress(raw_history: Variant) -> bool:
	if not raw_history is Array:
		return false
	for history_entry in raw_history:
		var metadata: Dictionary = _read_history_metadata(history_entry)
		if metadata.is_empty():
			continue
		if GAMEPLAY_HISTORY_TYPES.has(str(metadata.get("type", ""))):
			return true
	return false


func format_resume_hint_from_state(resume_state: Dictionary) -> String:
	var context: String = str(resume_state.get("context", CONTEXT_HUB))
	var track_key: String = str(resume_state.get("track_key", ""))
	var level_number: int = int(resume_state.get("level_number", 1))
	var track_label: String = str(_build_track_label_by_key().get(track_key, "Tu progreso"))
	if context == CONTEXT_LEVEL:
		return "%s capitulo %d" % [track_label, level_number]
	if context == CONTEXT_BOOK:
		return "%s seleccion de capitulos" % track_label
	return "el selector de modos"


func is_saved_level_completed(
	save_data: Dictionary,
	track_key: String,
	level_number: int
) -> bool:
	var stored_progress: Variant = save_data.get("progress", {})
	if not stored_progress is Dictionary:
		return false
	var stored_track_progress: Variant = stored_progress.get(track_key, [])
	if not stored_track_progress is Array:
		return false
	var level_index: int = level_number - 1
	if level_index < 0 or level_index >= stored_track_progress.size():
		return false
	return bool(stored_track_progress[level_index])


func _resolve_resume_state_with_history_fallback(
	save_data: Dictionary,
	normalized_resume_state: Dictionary
) -> Dictionary:
	var context: String = str(normalized_resume_state.get("context", CONTEXT_HUB))
	if context == CONTEXT_LEVEL:
		return normalized_resume_state
	var history_resume_state: Dictionary = _find_resume_state_in_history(save_data)
	if history_resume_state.is_empty():
		return normalized_resume_state
	return history_resume_state


func _find_resume_state_in_history(save_data: Dictionary) -> Dictionary:
	var stored_history_entries: Variant = save_data.get("history", [])
	if not stored_history_entries is Array:
		return {}

	for history_entry in stored_history_entries:
		var metadata: Dictionary = _read_history_metadata(history_entry)
		if metadata.is_empty():
			continue

		var entry_type: String = str(metadata.get("type", "")).strip_edges()
		if entry_type == "new_game":
			return {}

		var track_key: String = str(metadata.get("track", "")).strip_edges()
		if GameTrackCatalog.get_track_definition(track_key).is_empty():
			continue

		if entry_type == "manual_save":
			var manual_resume_state: Dictionary = _build_resume_state_from_manual_save_metadata(
				metadata
			)
			if not manual_resume_state.is_empty():
				return manual_resume_state

		if entry_type != "level_completed":
			continue

		var completed_resume_state: Dictionary = _build_resume_state_after_completed_level(
			save_data,
			metadata
		)
		if not completed_resume_state.is_empty():
			return completed_resume_state
	return {}


func _build_resume_state_from_manual_save_metadata(metadata: Dictionary) -> Dictionary:
	if str(metadata.get("context", "")).strip_edges() != CONTEXT_LEVEL:
		return {}
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	return build_resume_state_for_level(track_key, int(metadata.get("level", 1)))


func _build_resume_state_after_completed_level(
	save_data: Dictionary,
	metadata: Dictionary
) -> Dictionary:
	var track_key: String = str(metadata.get("track", "")).strip_edges()
	var completed_level: int = clampi(
		int(metadata.get("level", 1)),
		1,
		Global.get_track_level_count(track_key)
	)
	if GameTrackCatalog.get_track_definition(track_key).is_empty():
		return {}
	if not is_saved_level_completed(save_data, track_key, completed_level):
		return {}
	if completed_level >= Global.get_track_level_count(track_key):
		return default_resume_state()
	return build_resume_state_for_level(track_key, completed_level + 1)


func _build_history_entry(message: String, metadata: Dictionary) -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	}


func _read_history_metadata(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var metadata: Variant = entry.get("metadata", {})
	return metadata if metadata is Dictionary else {}


func _build_track_label_by_key() -> Dictionary:
	var track_label_by_key: Dictionary = {}
	for track_definition in GameTrackCatalog.get_track_definitions():
		var track_key: String = str(track_definition.get("key", "")).strip_edges()
		if track_key.is_empty():
			continue
		track_label_by_key[track_key] = str(track_definition.get("label", "")).strip_edges()
	return track_label_by_key