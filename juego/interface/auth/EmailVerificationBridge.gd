extends Node

const Service := preload("res://interface/auth/EmailVerificationService.gd")
const FlowHelper := preload("res://interface/auth/EmailVerificationFlowHelper.gd")
const MailVerifyNudgeHelperScript := preload("res://interface/auth/MailVerifyNudgeHelper.gd")
const StreakReminderNudgeHelperScript := preload("res://interface/auth/StreakReminderNudgeHelper.gd")
const StreakReminderHelperScript := preload("res://interface/auth/StreakReminderHelper.gd")

const ESCENAS_SIN_AVISO_MAIL := [
	"res://interface/evidente.tscn",
	"res://niveles/intro.tscn",
	"res://interface/auth/EmailVerification.tscn",
	"res://interface/auth.tscn",
	"res://API/Login.tscn",
]

signal aviso_verificacion(mensaje: String, es_ok: bool)

const NUDGE_REFRESH_INTERVAL_SECONDS := 60.0

var _nudge_global: CanvasLayer = null
var _streak_nudge_global: CanvasLayer = null
var _aviso_mail_activo_en_sesion := false
var _aviso_racha_activo_en_sesion := false
var _timer_refresco_nudges: Timer = null


func aviso_mail_habilitado() -> bool:
	return _aviso_mail_activo_en_sesion


func habilitar_aviso_mail() -> void:
	_aviso_mail_activo_en_sesion = true
	_aviso_racha_activo_en_sesion = true
	refrescar_nudge_global()


func deshabilitar_aviso_mail() -> void:
	_aviso_mail_activo_en_sesion = false
	_aviso_racha_activo_en_sesion = false
	refrescar_nudge_global()


## A diferencia del aviso de mail (que solo se activa tras un login explicito
## para no molestar apenas se restaura la sesion en silencio), el aviso de
## racha en riesgo/perdida es informativo y depende del reloj, no del login:
## debe poder mostrarse tambien cuando la sesion se restaura sola al abrir
## la app, que es el caso mas comun para un usuario que vuelve a jugar.
func habilitar_aviso_racha() -> void:
	_aviso_racha_activo_en_sesion = true
	refrescar_nudge_global()


func _ready() -> void:
	_nudge_global = MailVerifyNudgeHelperScript.instalar_en(
		self,
		Callable(self, "_on_nudge_verificar_ahora")
	)
	_streak_nudge_global = StreakReminderNudgeHelperScript.instalar_en(
		self,
		Callable(self, "_on_streak_nudge_accion")
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
	# El estado de racha ("warning" a las 18:00, "critical" a las 22:00) es
	# una función del reloj, no solo de datos: sin este timer, una sesión
	# quieta (sin abrir escenas ni pantallas nuevas) nunca vuelve a preguntar
	# y el aviso jamás aparece aunque cambie la hora.
	_timer_refresco_nudges = Timer.new()
	_timer_refresco_nudges.wait_time = NUDGE_REFRESH_INTERVAL_SECONDS
	_timer_refresco_nudges.autostart = true
	_timer_refresco_nudges.timeout.connect(refrescar_nudge_global)
	add_child(_timer_refresco_nudges)
	call_deferred("refrescar_nudge_global")


func refrescar_nudge_global() -> void:
	call_deferred("_refrescar_nudges_global")


func _on_sesion_restaurada(_user: Dictionary) -> void:
	# Restaurar cache en silencio: no mostrar el aviso de mail hasta login/Jugar
	# exitoso. El aviso de racha si se habilita: es informativo (racha en
	# riesgo o perdida) y no depende de que el login haya sido recien ahora.
	habilitar_aviso_racha()
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


func _refrescar_nudges_global() -> void:
	if is_instance_valid(_nudge_global):
		var ocultar_mail := (
			_escena_actual_sin_aviso_mail()
			or not _aviso_mail_activo_en_sesion
		)
		MailVerifyNudgeHelperScript.refrescar(_nudge_global, ocultar_mail)
	if is_instance_valid(_streak_nudge_global):
		# No se fuerza a ocultar por mail sin verificar: StreakReminderHelper
		# .resolver_nudge() ya arma la variante "Verificá tu mail" para ese
		# caso — ocultarla acá la dejaba sin mostrarse nunca.
		var ocultar_racha := (
			_escena_actual_sin_aviso_mail()
			or not _aviso_racha_activo_en_sesion
		)
		StreakReminderNudgeHelperScript.refrescar(_streak_nudge_global, ocultar_racha)


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


func _on_streak_nudge_accion(accion: int) -> void:
	match accion:
		StreakReminderHelperScript.AccionNudge.VERIFICAR_MAIL:
			_on_nudge_verificar_ahora()
		StreakReminderHelperScript.AccionNudge.ACTIVAR_RECORDATORIOS:
			_activar_recordatorios_desde_nudge()
		StreakReminderHelperScript.AccionNudge.ABRIR_PERFIL:
			GameSceneRouter.go_to_profile_editor(get_tree())
		StreakReminderHelperScript.AccionNudge.RECONOCER_PERDIDA:
			_reconocer_racha_perdida_desde_nudge()


func _reconocer_racha_perdida_desde_nudge() -> void:
	StreakReminderHelperScript.reconocer_racha_perdida()
	if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("ocultar"):
		_streak_nudge_global.call("ocultar")
	else:
		refrescar_nudge_global()


func _activar_recordatorios_desde_nudge() -> void:
	call_deferred("_activar_recordatorios_desde_nudge_async")


func _activar_recordatorios_desde_nudge_async() -> void:
	if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("set_procesando"):
		_streak_nudge_global.call("set_procesando", true)
	var resultado: Dictionary = await StreakReminderHelperScript.activar_recordatorios_en_servidor()
	if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("set_procesando"):
		_streak_nudge_global.call("set_procesando", false)
	var mensaje := str(resultado.get("error", "")).strip_edges()
	if bool(resultado.get("ok", false)):
		mensaje = "Recordatorios de racha activados. Te avisamos por mail cerca de las 18:00."
		aviso_verificacion.emit(mensaje, true)
		if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("ocultar"):
			_streak_nudge_global.call("ocultar")
		else:
			refrescar_nudge_global()
		call_deferred("_sincronizar_guardado_tras_activar_recordatorios")
		return
	if mensaje.is_empty():
		mensaje = "No se pudieron activar los recordatorios. Probá desde tu perfil."
	aviso_verificacion.emit(mensaje, false)
	if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("mostrar_aviso"):
		_streak_nudge_global.call("mostrar_aviso", mensaje, false)


func _sincronizar_guardado_tras_activar_recordatorios() -> void:
	if AuthApi.esta_logueado():
		AuthApi.aplicar_progreso_online_a_guardado_local()


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
	call_deferred("_ofrecer_recordatorios_tras_verificacion", retorno)
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(nodo_escena)
	return retorno


func _ofrecer_recordatorios_tras_verificacion(retorno: Dictionary) -> void:
	if str(retorno.get("outcome", "")) != "completado":
		return
	if not StreakReminderHelperScript.racha_en_riesgo():
		refrescar_nudge_global()
		return
	if StreakReminderHelperScript.notificaciones_activas_en_servidor():
		refrescar_nudge_global()
		return
	refrescar_nudge_global()


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
	if bool(result.get("ok", false)) and StreakReminderHelperScript.racha_en_riesgo():
		if not StreakReminderHelperScript.notificaciones_activas_en_servidor():
			if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("refrescar"):
				_streak_nudge_global.call("refrescar")
	var mensaje: String = str(result.get("mensaje", "")).strip_edges()
	if mensaje.is_empty():
		return
	var es_ok: bool = bool(result.get("ok", false))
	aviso_verificacion.emit(mensaje, es_ok)
	if is_instance_valid(_nudge_global) and _nudge_global.has_method("mostrar_aviso"):
		_nudge_global.call("mostrar_aviso", mensaje, es_ok)
	# También al nudge de racha: si "Verificar mail" se tocó desde ahí, el
	# resultado tiene que verse ahí, no solo en el aviso global de mail.
	if is_instance_valid(_streak_nudge_global) and _streak_nudge_global.has_method("mostrar_aviso"):
		_streak_nudge_global.call("mostrar_aviso", mensaje, es_ok)
