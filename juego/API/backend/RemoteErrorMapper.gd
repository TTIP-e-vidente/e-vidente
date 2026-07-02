class_name RemoteErrorMapper
extends RefCounted

## Normaliza códigos de error del backend/Edge a códigos canónicos y mensajes
## claros en español. Contrato: BACKEND/src/shared/contracts/api-contracts.ts.

const ALIAS_LEGACY := {
	"DUPLICATE_MAIL": "EMAIL_ALREADY_USED",
	"DUPLICATE_USERNAME": "USERNAME_ALREADY_USED",
	"INVALID_CODE": "OTP_INVALID",
	"CODE_EXPIRED": "OTP_EXPIRED",
	"TOO_MANY_ATTEMPTS": "OTP_TOO_MANY_ATTEMPTS",
	"RATE_LIMITED": "OTP_RATE_LIMITED",
	"PAYLOAD_TOO_LARGE": "AVATAR_TOO_LARGE",
}

const MENSAJES := {
	"EMAIL_NOT_VERIFIED": "Tenés que verificar tu correo antes de iniciar sesión.",
	"INVALID_CREDENTIALS": "Usuario o contraseña incorrectos.",
	"EMAIL_ALREADY_USED": "Ese mail ya está en uso.",
	"USERNAME_ALREADY_USED": "Ese nombre de usuario ya está en uso.",
	"OTP_INVALID": "Código incorrecto. Revisá el mail e intentá de nuevo.",
	"OTP_EXPIRED": "El código expiró. Pedí uno nuevo.",
	"OTP_TOO_MANY_ATTEMPTS": "Demasiados intentos. Pedí un código nuevo.",
	"OTP_RATE_LIMITED": "Esperá un momento antes de pedir otro código.",
	"AVATAR_TOO_LARGE": "La imagen supera los 3 MB permitidos.",
	"AVATAR_UNSUPPORTED_MIME": "Formato de imagen no soportado (usá PNG, JPG o WEBP).",
	"STORAGE_UNAVAILABLE": "No se pudo guardar tu avatar en la nube. Se reintenta más tarde.",
	"SYNC_DUPLICATE_IGNORED": "Esa partida ya estaba sincronizada.",
	"REMOTE_UNAVAILABLE": "No hay conexión con el servidor. Tu progreso queda guardado en este dispositivo.",
}


static func codigo_canonico(result: Dictionary) -> String:
	var code := str(result.get("code", "")).strip_edges()
	if code.is_empty() and int(result.get("status", -1)) == 0:
		return "REMOTE_UNAVAILABLE"
	return str(ALIAS_LEGACY.get(code, code))


static func es_email_no_verificado(result: Dictionary) -> bool:
	return codigo_canonico(result) == "EMAIL_NOT_VERIFIED"


static func mensaje(result: Dictionary, fallback: String = "") -> String:
	var canonico := codigo_canonico(result)
	if MENSAJES.has(canonico):
		return str(MENSAJES[canonico])
	var server_msg := str(result.get("error", "")).strip_edges()
	if not server_msg.is_empty():
		return server_msg
	return fallback if not fallback.is_empty() else "No se pudo completar la operación."
