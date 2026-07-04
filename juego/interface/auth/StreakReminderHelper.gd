extends RefCounted
class_name StreakReminderHelper

const ContextoSesionDeJuegoScript := preload("res://niveles/progress/ContextoSesionDeJuego.gd")

enum AccionNudge {
	NINGUNA,
	VERIFICAR_MAIL,
	ACTIVAR_RECORDATORIOS,
	ABRIR_PERFIL,
	RECONOCER_PERDIDA,
}


static func racha_en_riesgo() -> bool:
	if not AuthApi.esta_logueado():
		return false
	var modelo := _obtener_modelo_vista_racha()
	var streak_state := str(modelo.get("streak_state", ""))
	return streak_state == "warning" or streak_state == "critical"


## Racha cortada (vencida) todavia no reconocida por el jugador en este
## dispositivo. Se identifica por last_activity_day: mientras no vuelva a
## jugar, ese dia no cambia, asi que sirve como clave estable para no repetir
## el aviso una vez que el jugador ya lo vio.
static func racha_perdida_pendiente_de_aviso() -> bool:
	if not AuthApi.esta_logueado():
		return false
	var modelo := _obtener_modelo_vista_racha()
	if str(modelo.get("status_key", "")) != "expired":
		return false
	var dia := _dia_de_racha_perdida()
	if dia.is_empty():
		return false
	return not SaveManager.racha_perdida_ya_reconocida_para_dia(dia)


static func reconocer_racha_perdida() -> void:
	var dia := _dia_de_racha_perdida()
	if dia.is_empty():
		return
	SaveManager.marcar_racha_perdida_reconocida(dia)


static func _dia_de_racha_perdida() -> String:
	var estado := _obtener_estado_racha()
	return str(estado.get("last_activity_day", "")).strip_edges()


static func notificaciones_activas_en_servidor() -> bool:
	if not AuthApi.esta_logueado():
		return false
	return bool(AuthApi.obtener_usuario_online().get("email_notifications_enabled", false))


static func mail_verificado() -> bool:
	return AuthApi.esta_logueado() and AuthApi.mail_esta_verificado()


## Distingue "no hay mail cargado en la cuenta" de "hay mail pero no está
## verificado": ofrecerle "Verificar mail" a quien no tiene mail configurado
## termina siempre en un 422 del servidor, así que ese caso necesita otro
## texto y otra acción (ir al perfil a cargar un mail).
static func cuenta_sin_mail() -> bool:
	if not AuthApi.esta_logueado():
		return false
	return str(AuthApi.obtener_usuario_online().get("mail", "")).strip_edges().is_empty()


static func debe_mostrar_nudge() -> bool:
	if not AuthApi.esta_logueado():
		return false
	return racha_en_riesgo() or racha_perdida_pendiente_de_aviso()


static func resolver_nudge() -> Dictionary:
	if not debe_mostrar_nudge():
		return {"visible": false}

	if racha_perdida_pendiente_de_aviso():
		var modelo := _obtener_modelo_vista_racha()
		var previous: int = max(1, int(modelo.get("previous_count", 0)))
		var dia_label := "día" if previous == 1 else "días"
		return {
			"visible": true,
			"titulo": "Has perdido la racha",
			"cuerpo": (
				"Tu racha de %d %s se cortó. Volvé pronto para seguir con tu progreso."
				% [previous, dia_label]
			),
			"hint": "",
			"boton": "Entendido",
			"accion": AccionNudge.RECONOCER_PERDIDA,
		}

	if cuenta_sin_mail():
		return {
			"visible": true,
			"titulo": "Racha en riesgo",
			"cuerpo": (
				"Agregá un mail en tu perfil para poder recibir recordatorios "
				+ "cuando la racha esté en peligro."
			),
			"hint": "",
			"boton": "Agregar mail",
			"accion": AccionNudge.ABRIR_PERFIL,
		}

	if not mail_verificado():
		return {
			"visible": true,
			"titulo": "Racha en riesgo",
			"cuerpo": (
				"Verificá tu mail para poder recibir recordatorios "
				+ "cuando la racha esté en peligro."
			),
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

	# Ya está todo activado del lado del usuario (mail verificado y
	# recordatorios encendidos): igual mostramos el aviso in-game como
	# refuerzo visual, ya que el mail de las 18:00 puede tardar en llegar.
	return {
		"visible": true,
		"titulo": "Racha en riesgo",
		"cuerpo": (
			"Jugá hoy para no perder la racha. "
			+ "Si no jugás, te avisamos por mail cerca de las 18:00."
		),
		"hint": "",
		"boton": "",
		"accion": AccionNudge.NINGUNA,
	}


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


static func _obtener_estado_racha() -> Dictionary:
	var global_node := ContextoSesionDeJuegoScript.obtener_global()
	if global_node != null and global_node.has_method("obtener_estado_racha"):
		var raw: Variant = global_node.call("obtener_estado_racha")
		if raw is Dictionary:
			return raw as Dictionary
	return {}
