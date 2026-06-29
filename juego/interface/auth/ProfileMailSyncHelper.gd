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


static func _error_sync(code: String, error: String) -> Dictionary:
	return {
		"ok": false,
		"status": 409,
		"code": code,
		"error": error,
	}
