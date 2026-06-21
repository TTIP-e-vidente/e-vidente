extends RefCounted
class_name EmailVerificationService

const FlowHelper := preload("res://interface/auth/EmailVerificationFlowHelper.gd")


static func preparar_evaluacion_post_registro(result: Dictionary) -> Dictionary:
	var meta: Dictionary = result.get("verification", {}) as Dictionary
	if meta.is_empty():
		return {"needs_request": true, "evaluacion": {}}
	var evaluacion := AuthApi.evaluar_respuesta_verificacion({"ok": true}, meta)
	evaluacion["show_overlay"] = true
	_asegurar_feedback_default(evaluacion)
	return {"needs_request": false, "evaluacion": evaluacion}


static func preparar_evaluacion_tras_solicitud(res: Dictionary) -> Dictionary:
	return AuthApi.evaluar_respuesta_verificacion(res)


static func _asegurar_feedback_default(evaluacion: Dictionary) -> void:
	if str(evaluacion.get("feedback", "")).is_empty():
		evaluacion["feedback"] = "Ingresá el código de 6 dígitos que te enviamos por mail."
		evaluacion["feedback_ok"] = true


static func _resolver_navegacion(contexto: Node, opciones: Dictionary = {}) -> Dictionary:
	var nav := opciones.duplicate(true)
	if not nav.has("return_scene") or str(nav.get("return_scene", "")).strip_edges().is_empty():
		nav["return_scene"] = FlowHelper.detectar_escena_actual(contexto)
	if not nav.has("after_success") or str(nav.get("after_success", "")).strip_edges().is_empty():
		nav["after_success"] = "none"
	return nav


static func interpretar_outcome(outcome: String, obligatorio: bool) -> Dictionary:
	match outcome:
		"completado":
			if AuthApi.mail_esta_verificado():
				return {
					"ok": true,
					"mensaje": "Mail verificado. Te enviamos un mail de bienvenida.",
				}
			return {
				"ok": false,
				"mensaje": "No se pudo confirmar la verificación. Intentá de nuevo.",
			}
		"omitido":
			if obligatorio:
				return {
					"ok": false,
					"mensaje": "Verificá tu mail con el código de 6 dígitos para continuar.",
				}
			return {
				"ok": true,
				"mensaje": "Podés verificar tu mail más tarde desde el perfil.",
			}
		_:
			return {"ok": false, "mensaje": ""}


static func mostrar_escena(
		contexto: Node,
		evaluacion: Dictionary,
		obligatorio: bool,
		navegacion: Dictionary = {}
) -> Dictionary:
	evaluacion["show_overlay"] = true
	_asegurar_feedback_default(evaluacion)
	var nav := _resolver_navegacion(contexto, navegacion)
	var outcome := await FlowHelper.mostrar_y_esperar(
		contexto,
		evaluacion,
		obligatorio,
		nav
	)
	var result := interpretar_outcome(outcome, obligatorio)
	if not bool(result.get("ok", false)) and str(result.get("mensaje", "")).is_empty():
		var feedback := str(evaluacion.get("feedback", ""))
		if not feedback.is_empty():
			result["mensaje"] = feedback
	return result


static func ejecutar_post_registro(
		contexto: Node,
		result: Dictionary,
		navegacion: Dictionary = {}
) -> Dictionary:
	var nav := _resolver_navegacion(contexto, navegacion)
	if not nav.has("after_success") or str(nav.get("after_success")) == "none":
		nav["after_success"] = "login_continue_game"
	if str(nav.get("return_scene", "")).strip_edges().is_empty():
		nav["return_scene"] = GameSceneRouter.MAIN_MENU_SCENE_PATH

	var prep := preparar_evaluacion_post_registro(result)
	var evaluacion: Dictionary
	if bool(prep.get("needs_request", false)):
		var res := await AuthApi.solicitar_codigo_verificacion()
		evaluacion = preparar_evaluacion_tras_solicitud(res)
		if not bool(evaluacion.get("show_overlay", false)):
			return {
				"ok": false,
				"mensaje": str(evaluacion.get("feedback", "No se pudo enviar el código.")),
			}
		evaluacion["show_overlay"] = true
		_asegurar_feedback_default(evaluacion)
	else:
		evaluacion = prep.get("evaluacion", {}) as Dictionary
	return await mostrar_escena(contexto, evaluacion, true, nav)


static func ejecutar_pendiente(
		contexto: Node,
		obligatorio: bool = false,
		navegacion: Dictionary = {}
) -> Dictionary:
	var nav := _resolver_navegacion(contexto, navegacion)
	if obligatorio and str(nav.get("after_success")) == "none":
		nav["after_success"] = "login_continue_game"

	var res := await AuthApi.solicitar_codigo_verificacion()
	var evaluacion := preparar_evaluacion_tras_solicitud(res)
	if not bool(evaluacion.get("show_overlay", false)):
		return {
			"ok": false,
			"mensaje": str(evaluacion.get("feedback", "No se pudo enviar el código.")),
		}
	return await mostrar_escena(contexto, evaluacion, obligatorio, nav)


static func ejecutar_desde_nudge(contexto: Node) -> Dictionary:
	if not AuthApi.esta_logueado() or not AuthApi.mail_pendiente_verificacion():
		return {"ok": true, "mensaje": ""}
	return await ejecutar_pendiente(contexto, false, {"after_success": "none"})


static func ejecutar_desde_perfil(contexto: Node, evaluacion: Dictionary) -> Dictionary:
	if evaluacion.is_empty():
		evaluacion = {
			"show_overlay": true,
			"cooldown_seconds": 120.0,
			"feedback": "",
			"feedback_ok": true,
		}
	return await mostrar_escena(
		contexto,
		evaluacion,
		false,
		{
			"return_scene": GameSceneRouter.PROFILE_SCENE_PATH,
			"after_success": "profile_refresh",
		}
	)
