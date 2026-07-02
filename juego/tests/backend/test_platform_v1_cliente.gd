extends GdUnitTestSuite
class_name TestPlatformV1Cliente

## Tests deterministas (sin red) de las piezas cliente de la Platform V1:
## - RemoteErrorMapper: normalización de códigos y mensajes.
## - AvatarSyncService: marcador persistente de subida pendiente y MIME.

const RemoteErrorMapperScript := preload("res://API/backend/RemoteErrorMapper.gd")
const AvatarSyncServiceScript := preload("res://API/backend/sync/AvatarSyncService.gd")


func after_test() -> void:
	AvatarSyncServiceScript.limpiar_subida_pendiente("test_avatar_owner")


func test_email_not_verified_se_detecta() -> void:
	var result := {"ok": false, "status": 403, "code": "EMAIL_NOT_VERIFIED"}
	assert_bool(RemoteErrorMapperScript.es_email_no_verificado(result)).is_true()
	assert_str(RemoteErrorMapperScript.mensaje(result)).contains("verificar tu correo")


func test_alias_legacy_se_normalizan() -> void:
	assert_str(
		RemoteErrorMapperScript.codigo_canonico({"code": "DUPLICATE_MAIL"})
	).is_equal("EMAIL_ALREADY_USED")
	assert_str(
		RemoteErrorMapperScript.codigo_canonico({"code": "INVALID_CODE"})
	).is_equal("OTP_INVALID")
	assert_str(
		RemoteErrorMapperScript.codigo_canonico({"code": "PAYLOAD_TOO_LARGE"})
	).is_equal("AVATAR_TOO_LARGE")


func test_sin_conexion_es_remote_unavailable() -> void:
	var result := {"ok": false, "status": 0, "error": "No se pudo conectar al servidor"}
	assert_str(RemoteErrorMapperScript.codigo_canonico(result)).is_equal("REMOTE_UNAVAILABLE")
	assert_str(RemoteErrorMapperScript.mensaje(result)).contains("guardado en este dispositivo")


func test_mensaje_usa_error_del_servidor_como_fallback() -> void:
	var result := {"ok": false, "status": 422, "code": "ALGO_RARO", "error": "detalle server"}
	assert_str(RemoteErrorMapperScript.mensaje(result)).is_equal("detalle server")


func test_subida_pendiente_de_avatar_persiste_y_se_limpia() -> void:
	var owner := "test_avatar_owner"
	AvatarSyncServiceScript.limpiar_subida_pendiente(owner)
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente(owner)).is_false()

	AvatarSyncServiceScript.marcar_subida_pendiente(owner, "image/webp")
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente(owner)).is_true()
	var pendiente := AvatarSyncServiceScript.obtener_subida_pendiente(owner)
	assert_str(str(pendiente.get("mime_type", ""))).is_equal("image/webp")

	AvatarSyncServiceScript.limpiar_subida_pendiente(owner)
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente(owner)).is_false()


func test_subida_pendiente_no_mezcla_cuentas() -> void:
	AvatarSyncServiceScript.marcar_subida_pendiente("test_avatar_owner", "image/png")
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente("otra_cuenta")).is_false()


func test_mime_desde_ruta() -> void:
	assert_str(AvatarSyncServiceScript.mime_desde_ruta("user://a/avatar.jpg")).is_equal("image/jpeg")
	assert_str(AvatarSyncServiceScript.mime_desde_ruta("user://a/avatar.webp")).is_equal("image/webp")
	assert_str(AvatarSyncServiceScript.mime_desde_ruta("user://a/avatar.png")).is_equal("image/png")
