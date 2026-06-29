class_name ProfileMailSyncHelper
extends RefCounted

const SaveLocalProfileHelperScript := preload(
	"res://interface/save_local/profile/SaveLocalProfileHelper.gd"
)

## Comparación, refresh y validación del mail entre formulario, cache y servidor.


static func normalizar_mail(value: Variant) -> String:
	return str(value).strip_edges().to_lower()


static func mails_coinciden(a: Variant, b: Variant) -> bool:
	var left := normalizar_mail(a)
	var right := normalizar_mail(b)
	if left.is_empty() or right.is_empty():
		return left == right
	return left == right


static func obtener_mail_servidor() -> String:
	return str(AuthApi.obtener_usuario_online().get("mail", "")).strip_edges()


static func formulario_difiere_del_servidor(form_mail: String) -> bool:
	if not BackendSession.esta_logueado():
		return false
	var clean := form_mail.strip_edges()
	if clean.is_empty():
		return false
	return not mails_coinciden(clean, obtener_mail_servidor())


static func debe_forzar_sync_mail(form_mail: String, forzar_explicito: bool) -> bool:
	if forzar_explicito:
		return true
	return formulario_difiere_del_servidor(form_mail)


static func refrescar_perfil_servidor() -> Dictionary:
	if not BackendSession.esta_logueado():
		return {"ok": true}
	return await BackendSession.refrescar_usuario_en_cache()


static func validar_resultado_sync(form_mail: String, result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return result

	var clean := form_mail.strip_edges()
	if clean.is_empty():
		return result

	if bool(result.get("skipped", false)) and formulario_difiere_del_servidor(clean):
		return _error_sync(
			"MAIL_SYNC_SKIPPED",
			"El mail no se sincronizó con el servidor. Revisá la conexión y volvé a guardar."
		)

	if formulario_difiere_del_servidor(clean):
		return _error_sync(
			"MAIL_SYNC_MISMATCH",
			"El mail del servidor no coincide con el del formulario. Volvé a guardar el perfil."
		)

	return result


static func resolver_mail_visible(payload: Dictionary, fallback: String = "") -> String:
	var account_mail := str(payload.get("mail", "")).strip_edges()
	var pending := ""
	var verification: Variant = payload.get("verification", {})
	if verification is Dictionary:
		pending = str((verification as Dictionary).get("pending_target_mail", "")).strip_edges()

	if not account_mail.is_empty() and not pending.is_empty():
		if not mails_coinciden(account_mail, pending):
			return account_mail
		return pending

	if not account_mail.is_empty():
		return account_mail
	if not pending.is_empty():
		return pending

	var mail := obtener_mail_servidor()
	if not mail.is_empty():
		return mail

	return fallback.strip_edges()


static func mensaje_error(result: Dictionary, fallback: String = "") -> String:
	return AuthErrorFormatter.mensaje_perfil_sync(result, fallback)


static func validar_formato_mail(form_mail: String) -> Dictionary:
	var clean := form_mail.strip_edges()
	if clean.is_empty():
		return {"ok": false, "mensaje": "Completá un mail antes de continuar."}
	if not SaveLocalProfileHelperScript.es_email_valido(clean):
		return {"ok": false, "mensaje": "El mail no tiene un formato válido."}
	return {"ok": true, "mensaje": ""}


static func puede_solicitar_verificacion(form_mail: String) -> Dictionary:
	if not BackendSession.esta_logueado():
		return {"ok": false, "mensaje": "Iniciá sesión para verificar tu mail.", "code": "NOT_LOGGED_IN"}

	var formato := validar_formato_mail(form_mail)
	if not bool(formato.get("ok", false)):
		return {"ok": false, "mensaje": str(formato.get("mensaje", "")), "code": "INVALID_MAIL"}

	if formulario_difiere_del_servidor(form_mail):
		return {
			"ok": false,
			"mensaje": "Guardá el perfil para sincronizar el mail antes de verificar.",
			"code": "MAIL_NOT_SYNCED",
		}

	return {"ok": true, "mensaje": "", "code": ""}


static func preflight_envio_verificacion() -> Dictionary:
	if BackendConfig.email_via_supabase():
		return await _preflight_supabase_verificacion()
	return await _preflight_express_verificacion()


static func _preflight_supabase_verificacion() -> Dictionary:
	var health := await AuthApi.verificar_salud_email()
	if int(health.get("status", 0)) == 0:
		return {
			"ok": false,
			"mensaje": "No se pudo conectar a Supabase Edge Functions. Revisá supabase_functions_url en backend.local.json.",
			"code": "SUPABASE_OFFLINE",
		}

	var data: Variant = health.get("data", {})
	if not data is Dictionary:
		return {"ok": true, "mensaje": "", "code": ""}

	var email_data := data as Dictionary
	var configured := bool(email_data.get("delivery_configured", false))
	if not configured:
		var hints: Variant = email_data.get("hints", [])
		var hint := ""
		if hints is Array and not (hints as Array).is_empty():
			hint = str((hints as Array)[0])
		return {
			"ok": false,
			"mensaje": hint if not hint.is_empty() else "Brevo no configurado en Supabase Edge Functions.",
			"code": "EMAIL_UNAVAILABLE",
		}

	return {"ok": true, "mensaje": "", "code": ""}


static func _preflight_express_verificacion() -> Dictionary:
	var health := await AuthApi.verificar_salud_email()
	if int(health.get("status", 0)) == 0:
		return {
			"ok": false,
			"mensaje": "No se pudo conectar al backend. Levantá BACKEND con npm run dev.",
			"code": "BACKEND_OFFLINE",
		}

	var data: Variant = health.get("data", {})
	if not data is Dictionary:
		return {"ok": true, "mensaje": "", "code": ""}

	var email_data := data as Dictionary
	var enabled := bool(email_data.get("email_enabled", false))
	var configured := bool(email_data.get("delivery_configured", false))

	if enabled and not configured:
		var hints: Variant = email_data.get("hints", [])
		var hint := ""
		if hints is Array and not (hints as Array).is_empty():
			hint = str((hints as Array)[0])
		return {
			"ok": false,
			"mensaje": (
				hint
				if not hint.is_empty()
				else "El backend no tiene Brevo cargado. Reiniciá con npm run dev:restart en BACKEND."
			),
			"code": "EMAIL_UNAVAILABLE",
		}

	var probe: Variant = email_data.get("brevo_probe", {})
	if enabled and configured and probe is Dictionary:
		var probe_dict := probe as Dictionary
		if probe_dict.has("ok") and not bool(probe_dict.get("ok", true)):
			var probe_hint := str(probe_dict.get("hint", "")).strip_edges()
			var probe_error := str(probe_dict.get("error", "")).strip_edges()
			var mensaje := probe_hint if not probe_hint.is_empty() else probe_error
			if mensaje.is_empty():
				mensaje = "Brevo rechazó la conexión. Revisá BACKEND/docs/BREVO_SETUP.md."
			return {"ok": false, "mensaje": mensaje, "code": "BREVO_PROBE_FAILED"}

	return {"ok": true, "mensaje": "", "code": ""}


static func _error_sync(code: String, error: String) -> Dictionary:
	return {
		"ok": false,
		"status": 409,
		"code": code,
		"error": error,
	}
