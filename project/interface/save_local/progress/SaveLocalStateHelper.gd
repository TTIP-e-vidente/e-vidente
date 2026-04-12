extends RefCounted

func validate_save_name(title: String, min_length: int, max_length: int) -> Dictionary:
	var clean_title: String = _normalize_save_name(title)
	if clean_title.is_empty():
		return {"ok": true, "title": "", "message": ""}
	if clean_title.length() < min_length:
		return {
			"ok": false,
			"title": clean_title,
			"message": "Usa al menos %d caracteres para identificar la partida." % min_length
		}
	if clean_title.length() > max_length:
		return {
			"ok": false,
			"title": clean_title.left(max_length),
			"message": "El nombre puede tener hasta %d caracteres." % max_length
		}
	return {"ok": true, "title": clean_title, "message": ""}


func default_save_meta() -> Dictionary:
	return {
		"last_saved_at": "",
		"last_saved_reason": "",
		"write_count": 0
	}


func default_resume_state(resume_context_hub: String, archivero_scene: String) -> Dictionary:
	return {
		"context": resume_context_hub,
		"track_key": "",
		"scene_path": archivero_scene,
		"level_number": 1
	}


func normalize_resume_state(
	raw_resume_state: Dictionary,
	book_scenes: Dictionary,
	level_scenes: Dictionary,
	track_level_counts: Dictionary,
	archivero_scene: String,
	resume_context_hub: String,
	resume_context_book: String,
	resume_context_level: String,
	default_level_count: int
) -> Dictionary:
	var track_key: String = str(raw_resume_state.get("track_key", "")).strip_edges()
	var context: String = str(raw_resume_state.get("context", resume_context_hub)).strip_edges()
	var level_count: int = max(1, int(track_level_counts.get(track_key, default_level_count)))
	var level_number: int = clampi(int(raw_resume_state.get("level_number", 1)), 1, level_count)
	var is_known_track: bool = book_scenes.has(track_key) and level_scenes.has(track_key)

	if context == resume_context_book and is_known_track:
		return {
			"context": resume_context_book,
			"track_key": track_key,
			"scene_path": str(book_scenes.get(track_key, archivero_scene)),
			"level_number": level_number
		}

	if context == resume_context_level and is_known_track:
		return {
			"context": resume_context_level,
			"track_key": track_key,
			"scene_path": str(level_scenes.get(track_key, archivero_scene)),
			"level_number": level_number
		}

	return default_resume_state(resume_context_hub, archivero_scene)


func _normalize_save_name(title: String) -> String:
	var clean_title: String = title.strip_edges()
	for whitespace in ["\n", "\r", "\t"]:
		clean_title = clean_title.replace(whitespace, " ")
	while clean_title.contains("  "):
		clean_title = clean_title.replace("  ", " ")
	return clean_title


func summarize_progress_data(
	progress: Variant,
	track_keys: Array,
	track_level_counts: Dictionary
) -> Dictionary:
	var progress_data: Dictionary = {}
	var summary: Dictionary = {
		"total": 0,
		"max_total": 0
	}
	if progress is Dictionary:
		progress_data = progress
	for raw_track_key in track_keys:
		var track_key: String = str(raw_track_key)
		var completed_levels: int = count_completed_progress_track(progress_data.get(track_key, []))
		summary[track_key] = completed_levels
		summary["total"] = int(summary.get("total", 0)) + completed_levels
		summary["max_total"] = int(summary.get("max_total", 0)) + max(
			0,
			int(track_level_counts.get(track_key, 0))
		)
	return summary


func count_completed_progress_track(track_progress: Variant) -> int:
	var completed := 0
	if track_progress is Array:
		for entry in track_progress:
			if bool(entry):
				completed += 1
	return completed


func last_updated_at(state_data: Dictionary) -> String:
	var updated_at: String = str(state_data.get("updated_at", ""))
	if not updated_at.is_empty():
		return updated_at
	var save_meta: Variant = state_data.get("save_meta", {})
	if save_meta is Dictionary:
		updated_at = str(save_meta.get("last_saved_at", ""))
	if not updated_at.is_empty():
		return updated_at
	return str(state_data.get("created_at", ""))


func format_resume_hint_from_state(
	resume_state: Dictionary,
	resume_context_hub: String,
	resume_context_book: String,
	resume_context_level: String,
	track_labels: Dictionary
) -> String:
	var context: String = str(resume_state.get("context", resume_context_hub))
	var track_key: String = str(resume_state.get("track_key", ""))
	var level_number: int = int(resume_state.get("level_number", 1))
	var track_label: String = str(track_labels.get(track_key, "Tu progreso"))

	match context:
		resume_context_level:
			return "%s capitulo %d" % [track_label, level_number]
		resume_context_book:
			return "%s seleccion de capitulos" % track_label
		_:
			return "el selector de modos"
