extends RefCounted

const SAVE_PATH := "user://save_data.json"
const TEMP_PATH := "user://save_data.tmp.json"
const BACKUP_PATH := "user://save_data.backup.json"


func escribir(
	save_data: Dictionary,
	loaded_from: String,
	reason: String
) -> Dictionary:
	_estampar_meta_guardado(save_data, reason)
	var serialized: String = JSON.stringify(save_data.duplicate(true), "\t")

	if not _escribir_snapshot_temporal(serialized):
		return _falla("No se pudo abrir el archivo temporal del save.")

	if not _respaldar_principal_si_hace_falta(loaded_from):
		return _falla("No se pudo generar el backup del save local.")

	var replace_result: Dictionary = _reemplazar_principal_con_temporal(loaded_from)
	if not bool(replace_result.get("ok", false)):
		return _falla("No se pudo reemplazar el save principal.")

	return {
		"ok": true,
		"wrote_primary": bool(replace_result.get("wrote_primary", false)),
		"error_message": ""
	}


func _estampar_meta_guardado(save_data: Dictionary, reason: String) -> void:
	var raw_meta: Variant = save_data.get("save_meta", {})
	var save_meta: Dictionary = raw_meta if raw_meta is Dictionary else {}
	save_meta["last_saved_at"] = Time.get_datetime_string_from_system(false, true)
	save_meta["last_saved_reason"] = reason
	save_meta["write_count"] = max(0, int(save_meta.get("write_count", 0))) + 1
	save_data["save_meta"] = save_meta


func _escribir_snapshot_temporal(serialized: String) -> bool:
	var temp_path: String = _resolve_save_path(TEMP_PATH)
	_ensure_parent_dir(temp_path)
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null
	return true


func _respaldar_principal_si_hace_falta(loaded_from: String) -> bool:
	var save_path: String = _resolve_save_path(SAVE_PATH)
	if not FileAccess.file_exists(save_path):
		return true
	if loaded_from != "primary":
		return true
	return _copiar_archivo(save_path, _resolve_save_path(BACKUP_PATH))


func _reemplazar_principal_con_temporal(loaded_from: String) -> Dictionary:
	var save_path: String = _resolve_save_path(SAVE_PATH)
	var temp_path: String = _resolve_save_path(TEMP_PATH)
	var backup_path: String = _resolve_save_path(BACKUP_PATH)
	_eliminar_archivo(save_path)
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(save_path)
	) == OK:
		return {"ok": true, "wrote_primary": true}

	if FileAccess.file_exists(temp_path):
		if loaded_from != "primary":
			return {"ok": true, "wrote_primary": false}

	if FileAccess.file_exists(backup_path):
		_copiar_archivo(backup_path, save_path)

	return {"ok": false, "wrote_primary": false}


func _copiar_archivo(src: String, dst: String) -> bool:
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f = null
	_eliminar_archivo(dst)
	var df := FileAccess.open(dst, FileAccess.WRITE)
	if df == null:
		return false
	df.store_string(text)
	df.flush()
	df = null
	return true


func _eliminar_archivo(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _falla(error_message: String) -> Dictionary:
	return {"ok": false, "wrote_primary": false, "error_message": error_message}


static func _resolve_save_path(path: String) -> String:
	var override_dir: String = OS.get_environment("EVIDENTE_SAVE_DIR").strip_edges()
	if override_dir.is_empty():
		return path
	return override_dir.path_join(path.get_file())


static func _ensure_parent_dir(path: String) -> void:
	var dir_path: String = path.get_base_dir()
	if dir_path.is_empty() or dir_path == "user://":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
