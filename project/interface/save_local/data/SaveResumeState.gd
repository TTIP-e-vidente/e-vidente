extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const SaveCampanaHelperScript := preload(
	"res://interface/save_local/progress/campana/SaveCampanaHelper.gd"
)

const RESUME_CONTEXT_HUB := "hub"
const RESUME_CONTEXT_BOOK := "book"
const RESUME_CONTEXT_LEVEL := "level"

var _campana_helper: RefCounted


func _init() -> void:
	_campana_helper = SaveCampanaHelperScript.new()


func get_default_state(archivero_scene: String) -> Dictionary:
	return {
		"context": RESUME_CONTEXT_HUB,
		"track_key": "",
		"scene_path": archivero_scene,
		"level_number": 1
	}


func normalize(raw: Variant, archivero_scene: String) -> Dictionary:
	if not raw is Dictionary:
		return get_default_state(archivero_scene)

	var context: String = str(raw.get("context", RESUME_CONTEXT_HUB)).strip_edges()
	var track_key: String = str(raw.get("track_key", "")).strip_edges()
	if not GameTrackCatalog.has_track(track_key):
		return get_default_state(archivero_scene)

	var level_number: int = clampi(
		int(raw.get("level_number", 1)),
		1,
		GameTrackCatalog.get_track_level_count(track_key)
	)

	if context == RESUME_CONTEXT_BOOK:
		return {
			"context": RESUME_CONTEXT_BOOK,
			"track_key": track_key,
			"scene_path": GameTrackCatalog.get_book_scene_path(track_key),
			"level_number": level_number
		}

	if context == RESUME_CONTEXT_LEVEL:
		return {
			"context": RESUME_CONTEXT_LEVEL,
			"track_key": track_key,
			"scene_path": GameTrackCatalog.get_level_scene_path(track_key),
			"level_number": level_number
		}

	return get_default_state(archivero_scene)


func build_for_book(track_key: String, current_level: int) -> Dictionary:
	return {
		"context": RESUME_CONTEXT_BOOK,
		"track_key": track_key,
		"scene_path": GameTrackCatalog.get_book_scene_path(track_key),
		"level_number": clampi(
			current_level,
			1,
			GameTrackCatalog.get_track_level_count(track_key)
		)
	}


func build_for_level(track_key: String, level_number: int) -> Dictionary:
	return {
		"context": RESUME_CONTEXT_LEVEL,
		"track_key": track_key,
		"scene_path": GameTrackCatalog.get_level_scene_path(track_key),
		"level_number": clampi(
			level_number,
			1,
			GameTrackCatalog.get_track_level_count(track_key)
		)
	}


func resolve_from_save(save_snapshot: Dictionary, archivero_scene: String) -> Dictionary:
	var stored_resume_state: Variant = save_snapshot.get("resume_state", {})
	var normalized_resume: Dictionary = normalize(stored_resume_state, archivero_scene)
	if str(normalized_resume.get("context", RESUME_CONTEXT_HUB)) == RESUME_CONTEXT_LEVEL:
		return normalized_resume

	var resume_from_history: Dictionary = _find_resume_in_history(
		save_snapshot,
		archivero_scene
	)
	return resume_from_history if not resume_from_history.is_empty() else normalized_resume


func repair(save_snapshot: Dictionary, archivero_scene: String) -> bool:
	var current_resume: Dictionary = resolve_from_save(save_snapshot, archivero_scene)
	var saved_resume: Variant = save_snapshot.get("resume_state", {})
	var normalized_saved_resume: Dictionary = normalize(saved_resume, archivero_scene)
	if current_resume == normalized_saved_resume:
		return false
	save_snapshot["resume_state"] = current_resume
	return true


func format_hint(resume: Dictionary) -> String:
	var context: String = str(resume.get("context", RESUME_CONTEXT_HUB))
	var track_key: String = str(resume.get("track_key", ""))
	var level_number: int = int(resume.get("level_number", 1))
	var track_label: String = GameTrackCatalog.get_track_label(track_key, "Tu progreso")

	if context == RESUME_CONTEXT_LEVEL:
		return "%s capitulo %d" % [track_label, level_number]
	if context == RESUME_CONTEXT_BOOK:
		return "%s seleccion de capitulos" % track_label
	return "el selector de modos"


func _find_resume_in_history(save_snapshot: Dictionary, archivero_scene: String) -> Dictionary:
	var history_entries: Variant = save_snapshot.get("history", [])
	if not history_entries is Array:
		return {}

	for history_entry in history_entries:
		var history_metadata: Dictionary = _read_history_metadata(history_entry)
		if history_metadata.is_empty():
			continue

		var entry_type: String = str(history_metadata.get("type", "")).strip_edges()
		if entry_type == "new_game":
			return {}

		var track_key: String = str(history_metadata.get("track", "")).strip_edges()
		if not GameTrackCatalog.has_track(track_key):
			continue

		if (
			entry_type == "manual_save"
			and str(history_metadata.get("context", "")).strip_edges() == RESUME_CONTEXT_LEVEL
		):
			return build_for_level(track_key, int(history_metadata.get("level", 1)))

		if entry_type == "level_completed":
			var completed_level: int = clampi(
				int(history_metadata.get("level", 1)),
				1,
				GameTrackCatalog.get_track_level_count(track_key)
			)
			if not _is_level_completed_in_save(save_snapshot, track_key, completed_level):
				continue
			if completed_level >= GameTrackCatalog.get_track_level_count(track_key):
				return get_default_state(archivero_scene)
			return build_for_level(track_key, completed_level + 1)

	return {}


func _read_history_metadata(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var metadata: Variant = entry.get("metadata", {})
	return metadata if metadata is Dictionary else {}


func _is_level_completed_in_save(
	save_snapshot: Dictionary,
	track_key: String,
	level_number: int
) -> bool:
	var progress: Variant = save_snapshot.get("progress", {})
	if not progress is Dictionary:
		return false
	return _campana_helper.is_level_completed_in_save(progress, track_key, level_number)