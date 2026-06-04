extends Node

const DEMO_USERNAME := "bssm_user"
const DEMO_PASSWORD := "bssm_demo_1234"
const DEMO_NAME     := "BackendSession Smoke"
const DEMO_MAIL     := "bssm@evidente.local"


func _ready() -> void:
	BackendSession.login_succeeded.connect(_on_login_exitoso)
	BackendSession.login_failed.connect(_on_login_fallido)
	BackendSession.sync_succeeded.connect(_on_sync_exitosa)
	BackendSession.sync_failed.connect(_on_sync_fallida)
	BackendSession.session_expired.connect(_on_sesion_expirada)
	BackendSession.logout_completed.connect(_on_cierre_sesion_completado)

	_ejecutar_smoke.call_deferred()


func _ejecutar_smoke() -> void:
	print("[BSSM] ══════════════════════════════════════")
	print("[BSSM] BackendSession Smoke — E-VIDENTE")
	print("[BSSM] ══════════════════════════════════════")

	print("[BSSM] Paso 1 — iniciar sesión con usuario demo")
	var login_result := await BackendSession.iniciar_sesion(DEMO_USERNAME, DEMO_PASSWORD)

	if not BackendSession.esta_logueado():
		print("[BSSM] Login fallido, intentando registrar...")
		var reg_result := await BackendSession.registrar_cuenta(
			DEMO_USERNAME, DEMO_NAME, DEMO_MAIL, DEMO_PASSWORD
		)
		if not BackendSession.esta_logueado():
			push_error(
				"[BSSM] ERROR: No se pudo crear sesión. ¿El backend está corriendo? " +
				"Resultado: %s" % str(reg_result)
			)
			return

	print("[BSSM] esta_logueado: ", BackendSession.esta_logueado())
	print("[BSSM] usuario: ", BackendSession.obtener_usuario())

	print("[BSSM] Paso 2 — obtener usuario del servidor")
	var me_result := await BackendSession.obtener_usuario_del_servidor()
	print("[BSSM] obtener_usuario -> ok:", me_result.get("ok"), " status:", me_result.get("status"))

	print("[BSSM] Paso 3 — RunSummary fake")
	var summary := RunSummaryBuilder.construir(
		"sin_restriccion",
		"nodo_bssm_01",
		"completar",
		120,
		90.0,
		9,
		1,
		60,
		true,
		38,
	)
	print("[BSSM] summary.nodeId: ", summary.get("nodeId"))
	print("[BSSM] summary.finishedAt: ", summary.get("finishedAt"))

	print("[BSSM] Paso 4 — guardar progreso online")
	var save_result := await SyncApi.guardar_partida_en_servidor(summary)
	print("[BSSM] guardar_progreso -> ok:", save_result.get("ok"), " status:", save_result.get("status"))

	print("[BSSM] Paso 5 — obtener progreso del servidor")
	var progress_result := await BackendSession.obtener_progreso_del_servidor()
	print("[BSSM] obtener_progreso -> ok:", progress_result.get("ok"), " status:", progress_result.get("status"))

	print("[BSSM] Paso 6 — cerrar sesión")
	BackendSession.cerrar_sesion()

	print("[BSSM] ══════════════════════════════════════")
	print("[BSSM] Smoke completo.")
	print("[BSSM] ══════════════════════════════════════")


func _on_login_exitoso(user: Dictionary) -> void:
	print("[BSSM] >> login_succeeded: ", user)


func _on_login_fallido(reason: String) -> void:
	push_error("[BSSM] >> login_failed: " + reason)


func _on_sync_exitosa(progress: Dictionary) -> void:
	print("[BSSM] >> sync_succeeded — completed_nodes: ",
		progress.get("completedNodesCount", "n/a"))


func _on_sync_fallida(reason: String) -> void:
	push_error("[BSSM] >> sync_failed: " + reason)


func _on_sesion_expirada() -> void:
	push_error("[BSSM] >> session_expired: token vencido o inválido")


func _on_cierre_sesion_completado() -> void:
	print("[BSSM] >> logout_completed. esta_logueado: ", BackendSession.esta_logueado())
