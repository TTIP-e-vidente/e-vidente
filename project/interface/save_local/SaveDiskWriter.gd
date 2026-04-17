extends RefCounted

const SAVE_PATH := "user://save_data.json"
const TEMP_PATH := "user://save_data.tmp.json"
const BACKUP_PATH := "user://save_data.backup.json"

var _storage_helper: RefCounted


func _init(storage_helper: RefCounted) -> void:
	_storage_helper = storage_helper


func write(
	save_data: Dictionary,
	loaded_from: String,
	reason: String
) -> Dictionary:
	_stamp_save_meta(save_data, reason)
	var serialized: String = _storage_helper.serialize_save_data(save_data.duplicate(true))

	if not _write_temp_snapshot(serialized):
		return _failure("No se pudo abrir el archivo temporal del save.")

	if not _backup_primary_if_needed(loaded_from):
		return _failure("No se pudo generar el backup del save local.")

	var replace_result: Dictionary = _replace_primary_with_temp(loaded_from)
	if not bool(replace_result.get("ok", false)):
		return _failure("No se pudo reemplazar el save principal.")

	return {
		"ok": true,
		"wrote_primary": bool(replace_result.get("wrote_primary", false)),
		"error_message": ""
	}


func _stamp_save_meta(save_data: Dictionary, reason: String) -> void:
	var raw_meta: Variant = save_data.get("save_meta", {})
	var save_meta: Dictionary = raw_meta if raw_meta is Dictionary else {}
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = max(0, int(save_meta.get("write_count", 0))) + 1
	save_data["save_meta"] = save_meta


func _write_temp_snapshot(serialized: String) -> bool:
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null
	return true


func _backup_primary_if_needed(loaded_from: String) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	if loaded_from != "primary":
		return true
	return _storage_helper.copy_file(SAVE_PATH, BACKUP_PATH)


func _replace_primary_with_temp(loaded_from: String) -> Dictionary:
	_storage_helper.remove_file_if_exists(SAVE_PATH)
	if _storage_helper.move_file(TEMP_PATH, SAVE_PATH) == OK:
		return {"ok": true, "wrote_primary": true}

	if FileAccess.file_exists(TEMP_PATH):
		if loaded_from != "primary":
			return {"ok": true, "wrote_primary": false}

	if FileAccess.file_exists(BACKUP_PATH):
		_storage_helper.copy_file(BACKUP_PATH, SAVE_PATH)

	return {"ok": false, "wrote_primary": false}


func _failure(error_message: String) -> Dictionary:
	return {"ok": false, "wrote_primary": false, "error_message": error_message}
