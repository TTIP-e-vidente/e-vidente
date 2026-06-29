class_name SupabaseVerifyClient
extends Node

## Cliente HTTP para Edge Functions de verificación de email en Supabase.
## Delega transporte a SupabaseEdgeClient.

var _edge: SupabaseEdgeClient = null


func _obtener_edge() -> SupabaseEdgeClient:
	if _edge == null:
		_edge = SupabaseEdgeClient.new()
		add_child(_edge)
	return _edge


func solicitar_verificacion_email(token: String, mail_esperado: String = "") -> Dictionary:
	var body := {}
	var mail := mail_esperado.strip_edges()
	if not mail.is_empty():
		body["mail"] = mail
	return await _obtener_edge().enviar_post("verify-email-request", token, JSON.stringify(body))


func confirmar_verificacion_email(token: String, codigo: String) -> Dictionary:
	var body := JSON.stringify({"code": codigo})
	return await _obtener_edge().enviar_post("verify-email-confirm", token, body)


func verificar_salud_email() -> Dictionary:
	return await _obtener_edge().enviar_get("verify-email-health", "")
