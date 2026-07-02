class_name AvatarSyncService
extends RefCounted

## Estado de sincronización de avatar entre el save local y el backend.
## - Subida pendiente: si el upload falla por red, se registra acá y se
##   reintenta en el próximo login/carga online (el avatar local no se pierde).
## - La descarga con reintentos vive en BackendSession (necesita el árbol de
##   escena para los timers); acá están los delays y el marcador persistente.

const PENDING_UPLOAD_PATH := "user://avatars/pending_upload.json"
## Delays entre reintentos de descarga post-login (el primer intento es inmediato).
const DELAYS_DESCARGA: Array[float] = [5.0, 15.0]


static func marcar_subida_pendiente(owner: String, mime_type: String) -> void:
	var clean_owner := owner.strip_edges()
	if clean_owner.is_empty():
		return
	var data := _leer()
	data[clean_owner] = {
		"mime_type": mime_type,
		"marked_at": Time.get_datetime_string_from_system(true),
	}
	_escribir(data)
	print("[AvatarSyncService] Subida de avatar pendiente para ", clean_owner)


static func hay_subida_pendiente(owner: String) -> bool:
	var clean_owner := owner.strip_edges()
	if clean_owner.is_empty():
		return false
	return _leer().has(clean_owner)


static func obtener_subida_pendiente(owner: String) -> Dictionary:
	var data := _leer()
	var entry: Variant = data.get(owner.strip_edges(), {})
	return entry as Dictionary if entry is Dictionary else {}


static func limpiar_subida_pendiente(owner: String) -> void:
	var clean_owner := owner.strip_edges()
	if clean_owner.is_empty():
		return
	var data := _leer()
	if data.erase(clean_owner):
		_escribir(data)


static func _leer() -> Dictionary:
	if not FileAccess.file_exists(PENDING_UPLOAD_PATH):
		return {}
	var file := FileAccess.open(PENDING_UPLOAD_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


static func _escribir(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://avatars")
	)
	var file := FileAccess.open(PENDING_UPLOAD_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[AvatarSyncService] No se pudo escribir " + PENDING_UPLOAD_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


static func mime_desde_ruta(path: String) -> String:
	var lower := path.to_lower()
	if lower.ends_with(".jpg") or lower.ends_with(".jpeg"):
		return "image/jpeg"
	if lower.ends_with(".webp"):
		return "image/webp"
	return "image/png"
