extends Node

signal avatar_cargado(user_id: String, texture: Texture2D)


const DIR_CACHE := "user://lb_avatars"
const MAX_CONCURRENT := 4


var _memoria: Dictionary = {}
var _en_vuelo: Dictionary = {}
var _pendientes: Array[String] = []
var _activos: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_CACHE))


func obtener_textura(user_id: String, avatar_key: Variant) -> Texture2D:
	if user_id.is_empty() or avatar_key == null:
		return null
	var key := avatar_key as String if avatar_key is String else str(avatar_key)
	if key.is_empty():
		return null

	if _memoria.has(user_id):
		return _memoria[user_id] as Texture2D

	var path := _ruta_cache(user_id)
	if FileAccess.file_exists(path):
		var image := _cargar_imagen_desde_archivo(path)
		if image != null:
			var tex := ImageTexture.create_from_image(image)
			_memoria[user_id] = tex
			return tex
		# Cache corrupto: lo borramos para reintentar en la próxima carga.
		DirAccess.remove_absolute(path)

	_encolar_descarga(user_id)
	return null


func _encolar_descarga(user_id: String) -> void:
	if _en_vuelo.has(user_id) or user_id in _pendientes:
		return
	_pendientes.append(user_id)
	_procesar_cola()


func _procesar_cola() -> void:
	while _activos < MAX_CONCURRENT and not _pendientes.is_empty():
		var user_id := _pendientes.pop_front() as String
		_activos += 1
		_en_vuelo[user_id] = true
		_descargar_async(user_id)


func _descargar_async(user_id: String) -> void:
	var resultado: Dictionary = await BackendSession.descargar_avatar_publico(user_id)
	_activos = maxi(0, _activos - 1)
	_en_vuelo.erase(user_id)

	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", {})
		if datos is Dictionary:
			_persistir_desde_respuesta(user_id, datos as Dictionary)

	_procesar_cola()


func _persistir_desde_respuesta(user_id: String, datos: Dictionary) -> void:
	var b64: Variant = datos.get("data", null)
	var mime: String = str(datos.get("mimeType", "image/png"))
	if b64 == null or not b64 is String or (b64 as String).is_empty():
		return

	var clean_b64 := (b64 as String).replace("\n", "").replace("\r", "")
	var bytes := Marshalls.base64_to_raw(clean_b64)
	if bytes.is_empty():
		return

	var image := _cargar_imagen_desde_bytes(bytes, mime)
	if image == null:
		return

	var path := _ruta_cache(user_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

	var tex := ImageTexture.create_from_image(image)
	_memoria[user_id] = tex
	avatar_cargado.emit(user_id, tex)


func _cargar_imagen_desde_bytes(bytes: PackedByteArray, mime: String = "") -> Image:
	if bytes.is_empty():
		return null

	for formato in _orden_formatos_imagen(bytes, mime):
		var image := Image.new()
		if _cargar_imagen_formato(image, bytes, formato) == OK and not image.is_empty():
			return image
	return null


func _orden_formatos_imagen(bytes: PackedByteArray, mime: String) -> Array[String]:
	var orden: Array[String] = []
	var mime_lower := mime.strip_edges().to_lower()

	if mime_lower.contains("webp"):
		orden.append("webp")
	elif mime_lower.contains("jpeg") or mime_lower.contains("jpg"):
		orden.append("jpg")
	elif mime_lower.contains("png"):
		orden.append("png")

	if _bytes_parecen_webp(bytes):
		_agregar_formato_si_falta(orden, "webp")
	if _bytes_parecen_png(bytes):
		_agregar_formato_si_falta(orden, "png")
	if _bytes_parecen_jpeg(bytes):
		_agregar_formato_si_falta(orden, "jpg")

	for formato in ["webp", "png", "jpg"]:
		_agregar_formato_si_falta(orden, formato)
	return orden


func _agregar_formato_si_falta(orden: Array[String], formato: String) -> void:
	if formato not in orden:
		orden.append(formato)


func _cargar_imagen_formato(image: Image, bytes: PackedByteArray, formato: String) -> Error:
	match formato:
		"webp":
			return image.load_webp_from_buffer(bytes)
		"png":
			return image.load_png_from_buffer(bytes)
		"jpg":
			return image.load_jpg_from_buffer(bytes)
		_:
			return ERR_UNAVAILABLE


func _bytes_parecen_png(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 8 \
		and bytes[0] == 0x89 \
		and bytes[1] == 0x50 \
		and bytes[2] == 0x4E \
		and bytes[3] == 0x47


func _bytes_parecen_jpeg(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF


func _bytes_parecen_webp(bytes: PackedByteArray) -> bool:
	if bytes.size() < 12:
		return false
	return (
		bytes.slice(0, 4).get_string_from_ascii() == "RIFF"
		and bytes.slice(8, 12).get_string_from_ascii() == "WEBP"
	)


func _cargar_imagen_desde_archivo(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(path)
	return _cargar_imagen_desde_bytes(bytes)


func _ruta_cache(user_id: String) -> String:
	var safe := user_id.replace("/", "_").replace("\\", "_")
	return "%s/%s.img" % [DIR_CACHE, safe]
