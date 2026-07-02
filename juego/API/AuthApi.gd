class_name AuthApi
extends RefCounted

const MIN_PASSWORD_LENGTH := 8
const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)
const RemoteErrorMapperScript := preload("res://API/backend/RemoteErrorMapper.gd")


static func esta_logueado() -> bool:
	return BackendSession.esta_logueado()


static func tiene_datos_online_en_memoria() -> bool:
	return BackendSession.tiene_datos_online_en_memoria()


static func obtener_usuario() -> String:
	return BackendSession.obtener_usuario()


static func obtener_usuario_online() -> Dictionary:
	return BackendSession.obtener_usuario_en_cache()


static func mail_pendiente_verificacion() -> bool:
	# Login rechazado con EMAIL_NOT_VERIFIED: hay verificación pendiente
	# aunque todavía no exista sesión completa.
	if BackendSession.hay_verificacion_de_login_pendiente():
		return true
	if not esta_logueado():
		return false
	var user := obtener_usuario_online()
	var mail := str(user.get("mail", "")).strip_edges()
	if mail.is_empty():
		return false
	return not mail_verified_at_valido(user.get("mail_verified_at", null))


static func mail_verified_at_valido(verified_at: Variant) -> bool:
	if verified_at == null:
		return false
	var texto := str(verified_at).strip_edges()
	if texto.is_empty() or texto.to_lower() == "null":
		return false
	return true


static func mail_esta_verificado() -> bool:
	return esta_logueado() and not mail_pendiente_verificacion()


static func obtener_progreso_online() -> Dictionary:
	return BackendSession.obtener_progreso_online_en_cache()


static func verificar_servidor() -> Dictionary:
	return await BackendSession.verificar_estado_del_servidor()


static func verificar_stack() -> Dictionary:
	return await BackendSession.verificar_stack_completo()


static func mensaje_check_conexion(check: Dictionary, fallback: String = "") -> String:
	return AuthErrorFormatter.mensaje_desde_check_conexion(check, fallback)


static func resumen_conexion_ok(check: Dictionary) -> String:
	return AuthErrorFormatter.resumen_conexion_ok(check)


static func verificar_salud_email() -> Dictionary:
	return await BackendSession.verificar_salud_email()


static func obtener_estado_verificacion_email() -> Dictionary:
	return await BackendSession.obtener_estado_verificacion_email()


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


static func meta_verificacion_registro(result: Dictionary) -> Dictionary:
	var data: Variant = result.get("data", {})
	if not data is Dictionary:
		return {}
	var verification: Variant = (data as Dictionary).get("verification", {})
	if not verification is Dictionary:
		return {}
	var meta := verification as Dictionary
	if meta.is_empty():
		return {}
	return {
		"mail_changed": true,
		"code_send_status": str(meta.get("code_send_status", "")),
		"cooldown_seconds": int(meta.get("cooldown_seconds", 120)),
		"message": str(meta.get("message", "")),
		"target_mail": str(meta.get("target_mail", "")),
	}


static func _evaluacion_con_target_mail(evaluacion: Dictionary, meta: Dictionary) -> Dictionary:
	var enriched := evaluacion.duplicate(true)
	var target := str(meta.get("target_mail", "")).strip_edges()
	if target.is_empty():
		target = str(AuthApi.obtener_usuario_online().get("mail", "")).strip_edges()
	if not target.is_empty():
		enriched["target_mail"] = target
	return enriched


## Fuerza el mail del formulario/perfil como destino visible del overlay de verificaci?n.
static func evaluacion_con_mail_formulario(evaluacion: Dictionary, form_mail: String) -> Dictionary:
	var clean := form_mail.strip_edges()
	if clean.is_empty():
		return evaluacion
	return _evaluacion_con_target_mail(evaluacion, {"target_mail": clean})


static func _feedback_desde_meta(verification_meta: Dictionary, fallback: String) -> String:
	var msg := str(verification_meta.get("message", "")).strip_edges()
	return msg if not msg.is_empty() else fallback


## Unifica respuestas de env?o OTP (registro, PATCH perfil o POST verify-email/request).
## Retorna: show_overlay, cooldown_seconds, feedback, feedback_ok
static func evaluar_respuesta_verificacion(
		result: Dictionary,
		meta: Dictionary = {},
		fallback_cooldown: int = 120
) -> Dictionary:
	if int(result.get("status", 0)) == 0:
		return {
			"show_overlay": false,
			"cooldown_seconds": 0,
			"feedback": mensaje_error(
				result,
				BackendConfig.mensaje_sin_conexion_edge()
				if BackendConfig.es_modo_supabase_edge()
				else "No se pudo conectar al servidor. Levantá BACKEND con npm run dev."
			),
			"feedback_ok": false,
		}

	var verification_meta := meta if not meta.is_empty() else meta_verificacion_perfil(result)
	if not verification_meta.is_empty():
		var mail_changed := bool(verification_meta.get("mail_changed", false))
		var status := str(verification_meta.get("code_send_status", "")).strip_edges()
		var cooldown_meta := int(verification_meta.get("cooldown_seconds", fallback_cooldown))
		if mail_changed:
			return _evaluacion_con_target_mail(
				_evaluar_estado_envio_verificacion(status, cooldown_meta, verification_meta),
				verification_meta
			)

	if bool(result.get("skipped", false)):
		return {
			"show_overlay": false,
			"cooldown_seconds": 0,
			"feedback": "",
			"feedback_ok": true,
		}

	if bool(result.get("ok", false)):
		var data: Variant = result.get("data", {})
		if data is Dictionary:
			var api_status := str((data as Dictionary).get("status", "")).strip_edges()
			if api_status == "already_verified":
				return {
					"show_overlay": false,
					"cooldown_seconds": 0,
					"feedback": str(
						(data as Dictionary).get(
							"message",
							"Tu mail ya est? verificado."
						)
					),
					"feedback_ok": true,
				}
			if api_status == "dev_console":
				return {
					"show_overlay": true,
					"cooldown_seconds": 0,
					"feedback": str(
						(data as Dictionary).get(
							"message",
							"El c?digo est? en la consola del backend (dev_code)."
						)
					),
					"feedback_ok": true,
				}
		return _evaluacion_con_target_mail({
			"show_overlay": true,
			"cooldown_seconds": cooldown_verificacion(result, fallback_cooldown),
			"feedback": "Te enviamos el c?digo de verificaci?n. Revis? tu correo y la carpeta de spam.",
			"feedback_ok": true,
		}, meta_verificacion_perfil(result))

	var cooldown := cooldown_verificacion(result, 0)
	if cooldown > 0:
		return {
			"show_overlay": true,
			"cooldown_seconds": cooldown,
			"feedback": mensaje_verificacion(result, "Esper? antes de pedir otro c?digo."),
			"feedback_ok": false,
		}

	var code := str(result.get("code", "")).strip_edges()
	if code == "MAIL_OUT_OF_SYNC":
		return {
			"show_overlay": false,
			"cooldown_seconds": 0,
			"feedback": mensaje_verificacion(result, "Guard? el mail en tu perfil e intent? de nuevo."),
			"feedback_ok": false,
		}

	return {
		"show_overlay": false,
		"cooldown_seconds": 0,
		"feedback": mensaje_verificacion(result, "No se pudo enviar el c?digo."),
		"feedback_ok": false,
	}


static func _evaluar_estado_envio_verificacion(
		status: String,
		cooldown: int,
		verification_meta: Dictionary
) -> Dictionary:
	match status:
		"sent":
			return _evaluacion_con_target_mail({
				"show_overlay": true,
				"cooldown_seconds": cooldown,
				"feedback": _feedback_desde_meta(
					verification_meta,
					"Te enviamos el c?digo de verificaci?n (no el de bienvenida). Revis? tu casilla y spam."
				),
				"feedback_ok": true,
			}, verification_meta)
		"rate_limited":
			return _evaluacion_con_target_mail({
				"show_overlay": true,
				"cooldown_seconds": cooldown,
				"feedback": _feedback_desde_meta(
					verification_meta,
					"Ya hay un c?digo activo. Revis? tu casilla o esper? para reenviar."
				),
				"feedback_ok": false,
			}, verification_meta)
		"send_failed":
			return _evaluacion_con_target_mail({
				"show_overlay": false,
				"cooldown_seconds": 0,
				"feedback": _feedback_desde_meta(
					verification_meta,
					"No se pudo enviar el c?digo. Pod?s reintentar de inmediato."
				),
				"feedback_ok": false,
			}, verification_meta)
		"dev_console":
			return _evaluacion_con_target_mail({
				"show_overlay": true,
				"cooldown_seconds": 0,
				"feedback": _feedback_desde_meta(
					verification_meta,
					"Brevo no configurado. El c?digo est? en la consola del backend (dev_code)."
				),
				"feedback_ok": true,
			}, verification_meta)
		"skipped":
			return _evaluacion_con_target_mail({
				"show_overlay": false,
				"cooldown_seconds": 0,
				"feedback": _feedback_desde_meta(
					verification_meta,
					"Servicio de mail no disponible. En desarrollo, revis? la consola del backend."
				),
				"feedback_ok": false,
			}, verification_meta)
		_:
			return {
				"show_overlay": false,
				"cooldown_seconds": 0,
				"feedback": _feedback_desde_meta(
					verification_meta,
					"No se pudo enviar el c?digo de verificaci?n."
				),
				"feedback_ok": false,
			}

static func iniciar_sesion_completa(usuario_o_mail: String, clave: String) -> Dictionary:
	var auth := await iniciar_sesion(usuario_o_mail, clave)
	if not auth.get("ok", false):
		var fallo := _fallo("auth", auth, "No se pudo iniciar sesi?n.")
		if str(auth.get("code", "")) == "EMAIL_NOT_VERIFIED":
			# El server bloqueó el login hasta verificar el mail. BackendSession
			# ya guardó el token acotado; el caller debe abrir la pantalla de
			# verificación en modo obligatorio.
			fallo["requiere_verificacion"] = true
			fallo["mensaje"] = RemoteErrorMapperScript.mensaje(auth)
			var data: Variant = auth.get("data", {})
			if data is Dictionary:
				fallo["verification"] = (data as Dictionary).get("verification", {})
				fallo["user"] = (data as Dictionary).get("user", {})
		return fallo
	var datos := await cargar_datos_online()
	return _exito(auth, datos)


static func crear_cuenta_completa(
		usuario: String,
		clave: String,
		mail: String,
		nombre: String = "",
		fecha_nacimiento: Variant = null,
		acepta_notificaciones_mail: bool = false,
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
	var exito := _exito(auth, datos)
	var meta_registro := meta_verificacion_registro(auth)
	if not meta_registro.is_empty():
		exito["verification"] = meta_registro
	return exito


static func solicitar_codigo_verificacion(mail_esperado: String = "") -> Dictionary:
	var mail := mail_esperado.strip_edges()
	if mail.is_empty() and esta_logueado():
		mail = str(obtener_usuario_online().get("mail", "")).strip_edges()
	if mail.is_empty() and BackendSession.hay_verificacion_de_login_pendiente():
		mail = str(
			BackendSession.obtener_usuario_verificacion_pendiente().get("mail", "")
		).strip_edges()
	return await BackendSession.solicitar_verificacion_email(mail)


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
	# Vaciar la cola mientras el token sigue activo, antes de limpiar la sesi?n.
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
		acepta_notificaciones_mail: bool = false,
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
		return "Complet? usuario y contrase?a."
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
		return "Complet? usuario, nombre, mail y contrase?a."
	if clave.length() < MIN_PASSWORD_LENGTH:
		return "La contrase?a debe tener al menos %d caracteres." % MIN_PASSWORD_LENGTH
	var fecha_limpia := fecha_nacimiento.strip_edges()
	if fecha_limpia.is_empty():
		return "Ingres? tu fecha de nacimiento (AAAA-MM-DD)."
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
		"Sesi?n iniciada. Progreso sincronizado."
		if datos_ok
		else (
			"Sesi?n iniciada, pero no se pudo recuperar progreso online.\n"
			+ "Pod?s jugar igual; el save local sigue activo."
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
