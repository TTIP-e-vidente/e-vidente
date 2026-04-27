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
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(serialized)
	temp_file.flush()
	temp_file = null
	return true


func _respaldar_principal_si_hace_falta(loaded_from: String) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true
	if loaded_from != "primary":
		return true
	return _copiar_archivo(SAVE_PATH, BACKUP_PATH)


func _reemplazar_principal_con_temporal(loaded_from: String) -> Dictionary:
	_eliminar_archivo(SAVE_PATH)
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH)
	) == OK:
		return {"ok": true, "wrote_primary": true}

	if FileAccess.file_exists(TEMP_PATH):
		if loaded_from != "primary":
			return {"ok": true, "wrote_primary": false}

	if FileAccess.file_exists(BACKUP_PATH):
		_copiar_archivo(BACKUP_PATH, SAVE_PATH)

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
