class_name AuthApi
extends RefCounted

const MIN_PASSWORD_LENGTH := 8
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)


static func esta_logueado() -> bool:
	return BackendSession.esta_logueado()


static func tiene_datos_online_en_memoria() -> bool:
	return BackendSession.tiene_datos_online_en_memoria()


static func obtener_usuario() -> String:
	return BackendSession.obtener_usuario()


static func obtener_usuario_online() -> Dictionary:
	return BackendSession.obtener_usuario_en_cache()


static func obtener_progreso_online() -> Dictionary:
	return BackendSession.obtener_progreso_online_en_cache()


static func verificar_servidor() -> Dictionary:
	return await BackendSession.verificar_estado_del_servidor()


static func mensaje_error(result: Dictionary, fallback: String = "") -> String:
	return AuthErrorFormatter.mensaje_auth(result, fallback)


static func mensaje_verificacion(result: Dictionary, fallback: String = "") -> String:
	var msg := AuthErrorFormatter.mensaje_verificacion(result, fallback)
	if not msg.is_empty():
		return msg
	return mensaje_error(result, fallback)


static func cooldown_verificacion(result: Dictionary, fallback: int = 120) -> int:
	return AuthErrorFormatter.cooldown_verificacion(result, fallback)


static func meta_verificacion_perfil(result: Dictionary) -> Dictionary:
	var data: Variant = result.get("data", {})
	if not data is Dictionary:
		return {}
	var verification: Variant = (data as Dictionary).get("verification", {})
	if verification is Dictionary:
		return verification as Dictionary
	return {}

static func iniciar_sesion_completa(usuario_o_mail: String, clave: String) -> Dictionary:
	var auth := await iniciar_sesion(usuario_o_mail, clave)
	if not auth.get("ok", false):
		return _fallo("auth", auth, "No se pudo iniciar sesión.")
	var datos := await cargar_datos_online()
	return _exito(auth, datos)


static func crear_cuenta_completa(
		usuario: String,
		clave: String,
		mail: String,
		nombre: String = "",
		fecha_nacimiento: Variant = null,
		acepta_notificaciones_mail: bool = true,
		solicitar_verificacion_mail: bool = false
) -> Dictionary:
	var auth := await crear_cuenta(
		usuario,
		clave,
		mail,
		nombre,
		fecha_nacimiento,
		acepta_notificaciones_mail,
		solicitar_verificacion_mail
	)
	if not auth.get("ok", false):
		return _fallo("auth", auth, "No se pudo crear la cuenta.")
	var datos := await cargar_datos_online()
	return _exito(auth, datos)


static func solicitar_codigo_verificacion() -> Dictionary:
	return await BackendSession.solicitar_verificacion_email()


static func confirmar_codigo_verificacion(codigo: String) -> Dictionary:
	return await BackendSession.confirmar_verificacion_email(codigo)


static func precargar_datos_online() -> void:
	if not esta_logueado():
		return
	await cargar_datos_online()


static func cargar_datos_online() -> Dictionary:
	return await BackendSession.cargar_datos_online()


static func aplicar_progreso_online_a_guardado_local() -> void:
	## Compatibilidad: la sync ocurre en BackendSession.cargar_datos_online().
	if not esta_logueado():
		return
	SaveManager.sincronizar_con_cuenta_online(
		obtener_usuario_online(),
		obtener_progreso_online()
	)


static func cerrar_sesion() -> void:
	# Vaciar la cola mientras el token sigue activo, antes de limpiar la sesión.
	if esta_logueado():
		await SyncApi.esperar_drenaje_pendientes()
	SaveManager.al_cerrar_sesion_online()
	BackendSession.cerrar_sesion()


static func crear_cuenta(
		usuario: String,
		clave: String,
		mail: String,
		nombre: String = "",
		fecha_nacimiento: Variant = null,
		acepta_notificaciones_mail: bool = true,
		solicitar_verificacion_mail: bool = false
) -> Dictionary:
	var usuario_limpio := usuario.strip_edges()
	var mail_limpio := mail.strip_edges()
	var nombre_limpio := nombre.strip_edges()
	if nombre_limpio.is_empty():
		nombre_limpio = usuario_limpio
	return await BackendSession.registrar_cuenta(
		usuario_limpio,
		nombre_limpio,
		mail_limpio,
		clave,
		fecha_nacimiento,
		acepta_notificaciones_mail,
		solicitar_verificacion_mail
	)


static func iniciar_sesion(usuario_o_mail: String, clave: String) -> Dictionary:
	return await BackendSession.iniciar_sesion(usuario_o_mail.strip_edges(), clave)


static func validar_campos_login(usuario_o_mail: String, clave: String) -> String:
	if usuario_o_mail.strip_edges().is_empty() or clave.is_empty():
		return "Completá usuario y contraseña."
	return ""


static func validar_campos_registro(
		usuario: String,
		nombre: String,
		mail: String,
		clave: String,
		fecha_nacimiento: String
) -> String:
	if (
		usuario.strip_edges().is_empty()
		or nombre.strip_edges().is_empty()
		or mail.strip_edges().is_empty()
		or clave.is_empty()
	):
		return "Completá usuario, nombre, mail y contraseña."
	if clave.length() < MIN_PASSWORD_LENGTH:
		return "La contraseña debe tener al menos %d caracteres." % MIN_PASSWORD_LENGTH
	var fecha_limpia := fecha_nacimiento.strip_edges()
	if fecha_limpia.is_empty():
		return "Ingresá tu fecha de nacimiento (AAAA-MM-DD)."
	if not SaveLocalProfileHelperScript.es_fecha_nacimiento_valida(fecha_limpia):
		return "La fecha de nacimiento debe tener formato AAAA-MM-DD."
	return ""


static func _fallo(fase: String, result: Dictionary, fallback: String) -> Dictionary:
	return {
		"ok": false,
		"fase": fase,
		"mensaje": mensaje_error(result, fallback),
		"status": int(result.get("status", 0)),
		"error": str(result.get("error", "")),
		"code": str(result.get("code", "")),
	}


static func _exito(_auth: Dictionary, datos_online: Dictionary) -> Dictionary:
	var datos_ok := bool(datos_online.get("ok", false))
	var mensaje := (
		"Sesión iniciada. Progreso sincronizado."
		if datos_ok
		else (
			"Sesión iniciada, pero no se pudo recuperar progreso online.\n"
			+ "Podés jugar igual; el save local sigue activo."
		)
	)
	return {
		"ok": true,
		"fase": "listo",
		"cuenta_ok": datos_ok,
		"mensaje": mensaje,
		"user": datos_online.get("user", BackendSession.obtener_usuario_en_cache()),
		"progress": datos_online.get("progress", BackendSession.obtener_progreso_online_en_cache()),
	}
