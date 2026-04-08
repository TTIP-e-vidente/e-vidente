extends RefCounted


func load_available_save_data(save_path: String, temp_save_path: String, backup_save_path: String) -> Dictionary:
	for candidate_path in [save_path, temp_save_path, backup_save_path]:
		var candidate := read_save_data_from_path(candidate_path)
		if bool(candidate.get("ok", false)):
			return {
				"ok": true,
				"data": candidate.get("data", {}),
				"source": save_source_from_path(candidate_path, save_path, temp_save_path, backup_save_path)
			}
	return {"ok": false}


func save_source_from_path(path: String, save_path: String, temp_save_path: String, backup_save_path: String) -> String:
	match path:
		save_path:
			return "primary"
		temp_save_path:
			return "temp"
		backup_save_path:
			return "backup"
		_:
			return "default"


func read_save_data_from_path(path: String) -> Dictionary:
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

	var parsed_data: Variant = json.data
	if parsed_data is Dictionary:
		return {"ok": true, "data": parsed_data}
	return {"ok": false}


func serialize_save_data(save_data: Dictionary) -> String:
	return JSON.stringify(save_data, "\t")


func copy_file(source_path: String, destination_path: String) -> bool:
	var source_file := FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return false

	var file_contents := source_file.get_as_text()
	source_file = null
	remove_file_if_exists(destination_path)

	var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination_file == null:
		return false
	destination_file.store_string(file_contents)
	destination_file.flush()
	destination_file = null
	return true


func move_file(source_path: String, destination_path: String) -> int:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)


func remove_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))