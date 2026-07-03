extends RefCounted
class_name StreakReminderHelper

const ContextoSesionDeJuegoScript := preload("res://niveles/progress/ContextoSesionDeJuego.gd")

enum AccionNudge {
	NINGUNA,
	VERIFICAR_MAIL,
	ACTIVAR_RECORDATORIOS,
	ABRIR_PERFIL,
}


static func racha_en_riesgo() -> bool:
	if not AuthApi.esta_logueado():
		return false
	var modelo := _obtener_modelo_vista_racha()
	var streak_state := str(modelo.get("streak_state", ""))
	return streak_state == "warning" or streak_state == "critical"


static func notificaciones_activas_en_servidor() -> bool:
	if not AuthApi.esta_logueado():
		return false
	return bool(AuthApi.obtener_usuario_online().get("email_notifications_enabled", false))


static func mail_verificado() -> bool:
	return AuthApi.esta_logueado() and AuthApi.mail_esta_verificado()


static func debe_mostrar_nudge() -> bool:
	if not AuthApi.esta_logueado():
		return false
	if not racha_en_riesgo():
		return false
	if not mail_verificado():
		return true
	return not notificaciones_activas_en_servidor()


static func resolver_nudge() -> Dictionary:
	if not debe_mostrar_nudge():
		return {"visible": false}

	if not mail_verificado():
		return {
			"visible": true,
			"titulo": "Racha en riesgo",
			"cuerpo": "Verificá tu mail para poder recibir recordatorios cuando la racha esté en peligro.",
			"hint": "",
			"boton": "Verificar mail",
			"accion": AccionNudge.VERIFICAR_MAIL,
		}

	if not notificaciones_activas_en_servidor():
		return {
			"visible": true,
			"titulo": "Racha en riesgo",
			"cuerpo": "Activá recordatorios por mail y te avisamos si hoy no jugás.",
			"hint": "El aviso sale cerca de las 18:00 (hora Argentina).",
			"boton": "Activar recordatorios por mail",
			"accion": AccionNudge.ACTIVAR_RECORDATORIOS,
		}

	return {"visible": false}


static func mensaje_detalle_pantalla_racha() -> String:
	if not racha_en_riesgo():
		return ""
	if not AuthApi.esta_logueado():
		return "Jugá hoy para mantener la racha."
	if not mail_verificado():
		return "Jugá hoy para mantener la racha. Verificá tu mail para activar avisos."
	if notificaciones_activas_en_servidor():
		return (
			"Jugá hoy para mantener la racha. Si no jugás, te avisamos por mail cerca de las 18:00."
		)
	return (
		"Jugá hoy para mantener la racha. "
		+ "Activá recordatorios en tu perfil para recibir el aviso por mail."
	)


static func activar_recordatorios_en_servidor() -> Dictionary:
	if not AuthApi.esta_logueado():
		return {"ok": false, "error": "Sin sesión activa"}
	if not mail_verificado():
		return {"ok": false, "error": "Verificá tu mail antes de activar recordatorios."}

	var perfil := SaveManager.obtener_perfil_usuario_actual()
	var resultado := await BackendSession.actualizar_perfil_online(
		str(perfil.get("username", SaveManager.obtener_nombre_usuario_actual())),
		SaveManager.obtener_email_usuario_actual(),
		SaveManager.obtener_fecha_nacimiento_usuario_actual(),
		true
	)
	if bool(resultado.get("ok", false)):
		SaveManager.guardar_preferencia_notificaciones_mail_local(true)
		if AuthApi.esta_logueado():
			BackendSession.aplicar_email_notifications_en_cache(true)
	return resultado


static func _obtener_modelo_vista_racha() -> Dictionary:
	var global_node := ContextoSesionDeJuegoScript.obtener_global()
	if global_node != null and global_node.has_method("obtener_modelo_vista_racha"):
		var raw: Variant = global_node.call("obtener_modelo_vista_racha")
		if raw is Dictionary:
			return raw as Dictionary
	return {}
