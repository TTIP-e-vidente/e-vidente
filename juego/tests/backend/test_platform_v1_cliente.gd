extends GdUnitTestSuite
class_name TestPlatformV1Cliente

## Tests deterministas (sin red) de las piezas cliente de la Platform V1:
## - RemoteErrorMapper: normalización de códigos y mensajes.
## - AvatarSyncService: marcador persistente de subida pendiente y MIME.

const RemoteErrorMapperScript := preload("res://API/backend/RemoteErrorMapper.gd")
const AvatarSyncServiceScript := preload("res://API/backend/sync/AvatarSyncService.gd")
const AuthSessionScript := preload("res://API/backend/session/AuthSession.gd")


func after_test() -> void:
	AvatarSyncServiceScript.limpiar_subida_pendiente("test_avatar_owner")
	# BackendConfig es estático: restaurar el estado leído de disco para no
	# contaminar otras suites con la resolución auto de estos tests.
	BackendConfig.recargar()


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
	var duenio := "test_avatar_owner"
	AvatarSyncServiceScript.limpiar_subida_pendiente(duenio)
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente(duenio)).is_false()

	AvatarSyncServiceScript.marcar_subida_pendiente(duenio, "image/webp")
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente(duenio)).is_true()
	var pendiente := AvatarSyncServiceScript.obtener_subida_pendiente(duenio)
	assert_str(str(pendiente.get("mime_type", ""))).is_equal("image/webp")

	AvatarSyncServiceScript.limpiar_subida_pendiente(duenio)
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente(duenio)).is_false()


func test_subida_pendiente_no_mezcla_cuentas() -> void:
	AvatarSyncServiceScript.marcar_subida_pendiente("test_avatar_owner", "image/png")
	assert_bool(AvatarSyncServiceScript.hay_subida_pendiente("otra_cuenta")).is_false()


func test_mime_desde_ruta() -> void:
	assert_str(AvatarSyncServiceScript.mime_desde_ruta("user://a/avatar.jpg")).is_equal("image/jpeg")
	assert_str(AvatarSyncServiceScript.mime_desde_ruta("user://a/avatar.webp")).is_equal("image/webp")
	assert_str(AvatarSyncServiceScript.mime_desde_ruta("user://a/avatar.png")).is_equal("image/png")


func test_resolucion_auto_local_separa_entorno_de_datos() -> void:
	# Express local conectado a Postgres local → datos "local", cuentas @local.
	BackendConfig.aplicar_resolucion_auto(true, false)
	assert_str(BackendConfig.obtener_entorno_datos()).is_equal(BackendConfig.ENTORNO_LOCAL)
	assert_str(BackendConfig.obtener_sufijo_cuenta()).is_equal("@local")


func test_resolucion_auto_local_con_db_supabase_no_sufija() -> void:
	# Express local pero conectado a Supabase (dev:staging) → mismo espacio de
	# datos que Edge: sin sufijo, no hay nada que separar.
	BackendConfig.aplicar_resolucion_auto(true, true)
	assert_str(BackendConfig.obtener_entorno_datos()).is_equal(BackendConfig.ENTORNO_SUPABASE)
	assert_str(BackendConfig.obtener_sufijo_cuenta()).is_equal("")


func test_resolucion_auto_sin_local_usa_supabase() -> void:
	BackendConfig.aplicar_resolucion_auto(false, false)
	assert_str(BackendConfig.obtener_entorno_datos()).is_equal(BackendConfig.ENTORNO_SUPABASE)
	assert_str(BackendConfig.obtener_sufijo_cuenta()).is_equal("")
	assert_bool(BackendConfig.auto_esta_resuelto()).is_true()


func test_auth_session_clave_cuenta() -> void:
	var sesion := AuthSessionScript.new()
	sesion.establecer_sesion("token", "agus", "agus@local")
	assert_str(sesion.obtener_usuario()).is_equal("agus")
	assert_str(sesion.obtener_clave_cuenta()).is_equal("agus@local")

	# Sin clave explícita, la clave es el username (compat Supabase).
	sesion.establecer_sesion("token2", "margo")
	assert_str(sesion.obtener_clave_cuenta()).is_equal("margo")

	sesion.limpiar_sesion()
	assert_str(sesion.obtener_clave_cuenta()).is_equal("")
