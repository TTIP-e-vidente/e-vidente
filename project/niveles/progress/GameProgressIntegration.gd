extends RefCounted


static func register_level_resume(track_key: String, level_number: int) -> void:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return

	var level_count: int = Global.get_track_level_count(clean_track_key)
	if level_count <= 0:
		return

	SaveManager.set_resume_to_level(clean_track_key, clampi(level_number, 1, level_count))


static func save_level_progress(
	manager_level: Node,
	track_key: String,
	level_number: int
) -> Dictionary:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return {
			"partial_save_result": {},
			"save_status": {
				"state": "error",
				"last_error": "No se pudo resolver el track activo para guardar."
			}
		}

	if manager_level == null or not is_instance_valid(manager_level):
		return {
			"partial_save_result": {},
			"save_status": {
				"state": "error",
				"last_error": "No se pudo acceder al runtime del nivel para guardar."
			}
		}

	var level_count: int = Global.get_track_level_count(clean_track_key)
	if level_count <= 0:
		return {
			"partial_save_result": {},
			"save_status": {
				"state": "error",
				"last_error": "No se pudo resolver el capitulo activo para guardar."
			}
		}

	var resolved_level_number: int = clampi(level_number, 1, level_count)
	var partial_save_result: Dictionary = manager_level.store_partial_level_state(clean_track_key)
	SaveManager.set_resume_to_level(clean_track_key, resolved_level_number)
	SaveManager.record_manual_save()
	return {
		"partial_save_result": partial_save_result,
		"save_status": SaveManager.get_save_status()
	}


static func complete_level(track_key: String, level_number: int) -> void:
	var clean_track_key := track_key.strip_edges()
	if clean_track_key.is_empty():
		return

	var level_count: int = Global.get_track_level_count(clean_track_key)
	if level_count <= 0:
		return

	var resolved_level_number: int = clampi(level_number, 1, level_count)
	Global.mark_level_completed(clean_track_key, resolved_level_number)
	SaveManager.record_level_completed(clean_track_key, resolved_level_number)


static func record_question_session_completed(question_count: int, score: int) -> void:
	if question_count < 1:
		return
	Global.record_question_session_streak(question_count, score)
	SaveManager.persist_runtime_progress_to_current_save()