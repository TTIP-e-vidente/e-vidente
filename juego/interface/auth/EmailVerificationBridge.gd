extends Node

const Service := preload("res://interface/auth/EmailVerificationService.gd")
const FlowHelper := preload("res://interface/auth/EmailVerificationFlowHelper.gd")
const MailVerifyNudgeHelperScript := preload("res://interface/auth/MailVerifyNudgeHelper.gd")

const ESCENAS_SIN_AVISO_MAIL := [
	"res://interface/evidente.tscn",
	"res://niveles/intro.tscn",
	"res://interface/auth/EmailVerification.tscn",
	"res://interface/auth.tscn",
	"res://API/Login.tscn",
]

signal aviso_verificacion(mensaje: String, es_ok: bool)

var _nudge_global: CanvasLayer = null
var _aviso_mail_activo_en_sesion := false


func aviso_mail_habilitado() -> bool:
	return _aviso_mail_activo_en_sesion


func habilitar_aviso_mail() -> void:
	_aviso_mail_activo_en_sesion = true
	refrescar_nudge_global()


func deshabilitar_aviso_mail() -> void:
	_aviso_mail_activo_en_sesion = false
	refrescar_nudge_global()


func _ready() -> void:
	_nudge_global = MailVerifyNudgeHelperScript.instalar_en(
		self,
		Callable(self, "_on_nudge_verificar_ahora")
	)
	if BackendSession.has_signal("session_restored"):
		BackendSession.session_restored.connect(_on_sesion_restaurada)
	if BackendSession.has_signal("login_succeeded"):
		BackendSession.login_succeeded.connect(_on_login_exitoso)
	if BackendSession.has_signal("logout_completed"):
		BackendSession.logout_completed.connect(_on_logout_completado)
	if BackendSession.has_signal("session_expired"):
		BackendSession.session_expired.connect(_on_logout_completado)
	if get_tree() != null:
		get_tree().node_added.connect(_on_arbol_cambiado)
	call_deferred("refrescar_nudge_global")


func refrescar_nudge_global() -> void:
	call_deferred("_refrescar_nudge_global")


func _on_sesion_restaurada(_user: Dictionary) -> void:
	# Restaurar cache en silencio: no mostrar avisos hasta login/Jugar exitoso.
	_ejecutar_en_segundo_plano(
		func() -> Dictionary:
			await BackendSession.refrescar_usuario_en_cache()
			return {"ok": true, "mensaje": ""}
	)


func _on_login_exitoso(_user: Dictionary) -> void:
	habilitar_aviso_mail()


func _on_logout_completado(_payload: Variant = null) -> void:
	deshabilitar_aviso_mail()


func _on_arbol_cambiado(_node: Node) -> void:
	refrescar_nudge_global()


func _refrescar_nudge_global() -> void:
	if not is_instance_valid(_nudge_global):
		return
	var ocultar := (
		_escena_actual_sin_aviso_mail()
		or not _aviso_mail_activo_en_sesion
	)
	MailVerifyNudgeHelperScript.refrescar(_nudge_global, ocultar)


func _escena_actual_sin_aviso_mail() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return true
	var scene_path := str(tree.current_scene.scene_file_path).strip_edges()
	return ESCENAS_SIN_AVISO_MAIL.has(scene_path)


func _on_nudge_verificar_ahora() -> void:
	var return_scene: String = GameSceneRouter.MAIN_MENU_SCENE_PATH
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var path := str(tree.current_scene.scene_file_path).strip_edges()
		if not path.is_empty():
			return_scene = path
	iniciar_pendiente(false, {"return_scene": return_scene, "after_success": "none"})


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
			_refrescar_perfil_tras_verificacion(nodo_escena)
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(nodo_escena)
	return retorno


func _refrescar_perfil_tras_verificacion(nodo_escena: Node) -> void:
	if not nodo_escena.has_method("_refrescar_tras_verificacion_mail"):
		return
	call_deferred("_await_refresco_perfil", nodo_escena)


func _await_refresco_perfil(nodo_escena: Node) -> void:
	if not is_instance_valid(nodo_escena):
		return
	if not nodo_escena.has_method("_refrescar_tras_verificacion_mail"):
		return
	await nodo_escena._refrescar_tras_verificacion_mail()


func _ejecutar_en_segundo_plano(job: Callable) -> void:
	call_deferred("_run_job", job)


func _run_job(job: Callable) -> void:
	if not job.is_valid():
		return
	var result: Variant = await job.call()
	if result is Dictionary:
		_procesar_resultado_verificacion(result as Dictionary)


func _procesar_resultado_verificacion(result: Dictionary) -> void:
	refrescar_nudge_global()
	var mensaje: String = str(result.get("mensaje", "")).strip_edges()
	if mensaje.is_empty():
		return
	var es_ok: bool = bool(result.get("ok", false))
	aviso_verificacion.emit(mensaje, es_ok)
	if is_instance_valid(_nudge_global) and _nudge_global.has_method("mostrar_aviso"):
		_nudge_global.call("mostrar_aviso", mensaje, es_ok)
