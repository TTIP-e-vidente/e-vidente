class_name AuthApi
extends RefCounted

const MIN_PASSWORD_LENGTH := 8


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


static func mensaje_servidor_listo() -> String:
	return AuthErrorFormatter.mensaje_servidor_listo()


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
		nombre: String = ""
) -> Dictionary:
	var auth := await crear_cuenta(usuario, clave, mail, nombre)
	if not auth.get("ok", false):
		return _fallo("auth", auth, "No se pudo crear la cuenta.")
	var datos := await cargar_datos_online()
	return _exito(auth, datos)


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
	SaveManager.al_cerrar_sesion_online()
	BackendSession.cerrar_sesion()


static func crear_cuenta(
		usuario: String,
		clave: String,
		mail: String,
		nombre: String = ""
) -> Dictionary:
	var usuario_limpio := usuario.strip_edges()
	var mail_limpio := mail.strip_edges()
	var nombre_limpio := nombre.strip_edges()
	if nombre_limpio.is_empty():
		nombre_limpio = usuario_limpio
	return await BackendSession.registrar_cuenta(
		usuario_limpio, nombre_limpio, mail_limpio, clave
	)


static func iniciar_sesion(usuario_o_mail: String, clave: String) -> Dictionary:
	return await BackendSession.iniciar_sesion(usuario_o_mail.strip_edges(), clave)


static func validar_campos_login(usuario_o_mail: String, clave: String) -> String:
	if usuario_o_mail.strip_edges().is_empty() or clave.is_empty():
		return "Completá usuario y contraseña."
	return ""


static func validar_campos_registro(
		usuario: String, mail: String, clave: String) -> String:
	if usuario.strip_edges().is_empty() or mail.strip_edges().is_empty() or clave.is_empty():
		return "Completá usuario, mail y contraseña."
	if clave.length() < MIN_PASSWORD_LENGTH:
		return "La contraseña debe tener al menos %d caracteres." % MIN_PASSWORD_LENGTH
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
