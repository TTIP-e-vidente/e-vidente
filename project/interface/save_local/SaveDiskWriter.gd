extends RefCounted

var _storage_helper: RefCounted
var _save_path: String
var _temp_path: String
var _backup_path: String


func _init(
	storage_helper: RefCounted,
	save_path: String,
	temp_path: String,
	backup_path: String
) -> void:
	_storage_helper = storage_helper
	_save_path = save_path
	_temp_path = temp_path
	_backup_path = backup_path

func write(
	save_data: Dictionary,
	runtime_status: Dictionary,
	reason: String
) -> Dictionary:
	_stamp_save_meta(save_data, reason)
	var serialized: String = _storage_helper.serialize_save_data(save_data.duplicate(true))

	if not _write_temp_snapshot(serialized):
		return _failure("No se pudo abrir el archivo temporal del save.")

	if not _backup_primary_if_needed(runtime_status):
		return _failure("No se pudo generar el backup del save local.")

	var replace_result: Dictionary = _replace_primary_with_temp(runtime_status)
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
	var temp_file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null
	return true


func _backup_primary_if_needed(runtime_status: Dictionary) -> bool:
	if not FileAccess.file_exists(_save_path):
		return true
	if str(runtime_status.get("last_loaded_from", "primary")) != "primary":
		return true
	return _storage_helper.copy_file(_save_path, _backup_path)


func _replace_primary_with_temp(runtime_status: Dictionary) -> Dictionary:
	_storage_helper.remove_file_if_exists(_save_path)
	if _storage_helper.move_file(_temp_path, _save_path) == OK:
		return {"ok": true, "wrote_primary": true}

	if FileAccess.file_exists(_temp_path):
		if str(runtime_status.get("last_loaded_from", "primary")) != "primary":
			return {"ok": true, "wrote_primary": false}

	if FileAccess.file_exists(_backup_path):
		_storage_helper.copy_file(_backup_path, _save_path)

	return {"ok": false, "wrote_primary": false}


func _failure(error_message: String) -> Dictionary:
	return {"ok": false, "wrote_primary": false, "error_message": error_message}
