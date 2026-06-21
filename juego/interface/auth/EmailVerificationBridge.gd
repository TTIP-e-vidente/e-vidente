extends Node

const Service := preload("res://interface/auth/EmailVerificationService.gd")
const FlowHelper := preload("res://interface/auth/EmailVerificationFlowHelper.gd")


func iniciar_post_registro(result: Dictionary, navegacion: Dictionary = {}) -> void:
	_ejecutar_en_segundo_plano(
		func() -> Dictionary:
			return await Service.ejecutar_post_registro(self, result, navegacion)
	)


func iniciar_pendiente(obligatorio: bool = false, navegacion: Dictionary = {}) -> void:
	_ejecutar_en_segundo_plano(
		func() -> Dictionary:
			return await Service.ejecutar_pendiente(self, obligatorio, navegacion)
	)


func iniciar_desde_nudge() -> void:
	_ejecutar_en_segundo_plano(
		func() -> Dictionary:
			return await Service.ejecutar_desde_nudge(self)
	)


func iniciar_desde_perfil(evaluacion: Dictionary) -> void:
	_ejecutar_en_segundo_plano(
		func() -> Dictionary:
			return await Service.ejecutar_desde_perfil(self, evaluacion)
	)


func procesar_retorno_escena(nodo_escena: Node) -> Dictionary:
	if nodo_escena == null or nodo_escena.get_tree() == null:
		return {}
	var retorno := FlowHelper.consumir_retorno(nodo_escena.get_tree().root)
	if retorno.is_empty():
		return retorno
	if str(retorno.get("outcome", "")) != "completado":
		return retorno
	match str(retorno.get("after_success", "none")):
		"login_continue_game":
			if nodo_escena.has_method("_continuar_a_juego"):
				nodo_escena.call("_continuar_a_juego")
		"login_continue_profile":
			if nodo_escena.has_method("_mostrar_perfil"):
				nodo_escena.call("_mostrar_perfil")
		"profile_refresh":
			if nodo_escena.has_method("_refrescar_tras_verificacion_mail"):
				nodo_escena.call("_refrescar_tras_verificacion_mail")
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(nodo_escena)
	return retorno


func _ejecutar_en_segundo_plano(job: Callable) -> void:
	call_deferred("_run_job", job)


func _run_job(job: Callable) -> void:
	if job.is_valid():
		await job.call()
